import UIKit
import MiniFuture

class VCardSourceDetailViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
  private let source: VCardSource
  private let isNewSource: Bool
  private let urlDownloadFactory: URLDownloadFactory
  private let onSave: VCardSource -> Void

  private var tableView: UITableView!

  private var noteLabel: MultilineLabel!
  private var vcardURLValidationResultView: LabeledActivityIndicator!

  private var nameCell: LabeledTextFieldCell!
  private var vcardURLCell: LabeledTextFieldCell!
  private var loginURLCell: LabeledTextFieldCell!
  private var authMethodCell: LabeledSelectionCell<HTTPRequest.AuthenticationMethod>!
  private var usernameCell: LabeledTextFieldCell!
  private var passwordCell: LabeledTextFieldCell!
  private var isEnabledCell: LabeledSwitchCell!

  private var nameValidator: InputValidator<String>!
  private var vcardURLValidator: InputValidator<VCardSource.Connection>!

  private var cellsByIndexPath: [Int: [Int: UITableViewCell]]!

  private var shouldCallOnSave: Bool
  private var isFirstTimeViewAppears = true

  private var focusedTextField: UITextField?

  init(
    source: VCardSource,
    isNewSource: Bool,
    downloadsWith urlDownloadFactory: URLDownloadFactory,
    saveHandler onSave: VCardSource -> Void)
  {
    self.source = source
    self.isNewSource = isNewSource
    self.urlDownloadFactory = urlDownloadFactory
    self.onSave = onSave
    self.shouldCallOnSave = !isNewSource

    super.init(nibName: nil, bundle: nil)

    if isNewSource {
      navigationItem.title = "Add vCard Source"

      navigationItem.leftBarButtonItem = UIBarButtonItem(
        barButtonSystemItem: .Cancel,
        target: self,
        action: "cancel:")

      navigationItem.rightBarButtonItem = UIBarButtonItem(
        barButtonSystemItem: .Done,
        target: self,
        action: "done:")
    }
  }

  required init?(coder decoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func loadView() {
    func makeTableView() -> UITableView {
      let tv = UITableView(frame: CGRect.zero, style: .Grouped)
      tv.estimatedSectionHeaderHeight = 50
      tv.estimatedRowHeight = 40
      tv.rowHeight = UITableViewAutomaticDimension
      tv.sectionFooterHeight = 0
      tv.delegate = self
      tv.dataSource = self
      return tv
    }

    func makeTextFieldDelegate(
      changeTextHandler onChange: ProxyTextFieldDelegate.OnTextChangeCallback? = nil)
      -> UITextFieldDelegate
    {
      return ProxyTextFieldDelegate(
        beginEditingHandler: { [unowned self] tf in
          self.focusedTextField = tf
        },
        endEditingHandler: { [unowned self] _ in
          self.focusedTextField = nil
        },
        shouldReturnHandler: { tf in
          tf.resignFirstResponder()
          return true
        },
        changeHandler: onChange)
    }

    func makeNameCell() -> LabeledTextFieldCell {
      return LabeledTextFieldCell(
        label: "Name",
        value: source.name,
        autocapitalizationType: .Sentences,
        autocorrectionType: .Yes,
        spellCheckingType: .Default,
        textFieldDelegate: makeTextFieldDelegate(
          changeTextHandler: { [unowned self] _, text in
            self.nameValidator.validate(text)
          }
        ))
    }

    func makeVCardURLCell() -> LabeledTextFieldCell {
      return LabeledTextFieldCell(
        label: "vCard URL",
        value: source.connection.vcardURL,
        textFieldDelegate: makeTextFieldDelegate(
          changeTextHandler: { [unowned self] _, text in
            self.validateVCardURL(vcardURL: text)
          }
        ))
    }

    func makeLoginURLCell() -> LabeledTextFieldCell {
      return LabeledTextFieldCell(
        label: "Login URL",
        value: source.connection.loginURL ?? "",
        textFieldDelegate: makeTextFieldDelegate(
          changeTextHandler: { [unowned self] _, text in
            self.validateVCardURL(loginURL: text)
          }
        ))
    }

    func makeAuthMethodCell() -> LabeledSelectionCell<HTTPRequest.AuthenticationMethod> {
      return LabeledSelectionCell(
        label: "Authentication",
        selection: SelectionOption(
          data: source.connection.authenticationMethod,
          shortDescription: source.connection.authenticationMethod.shortDescription))
    }

    func makeUsernameCell() -> LabeledTextFieldCell {
      return LabeledTextFieldCell(
        label: "Username",
        value: source.connection.username ?? "",
        textFieldDelegate: makeTextFieldDelegate(
          changeTextHandler: { [unowned self] _, text in
            self.validateVCardURL(username: text)
          }
        ))
    }

    func makePasswordCell() -> LabeledTextFieldCell {
      return LabeledTextFieldCell(
        label: "Password",
        value: source.connection.password ?? "",
        isSecure: true,
        textFieldDelegate: makeTextFieldDelegate(
          changeTextHandler: { [unowned self] _, text in
            self.validateVCardURL(password: text)
          }
        ))
    }

    func makeIsEnabledCell() -> LabeledSwitchCell {
      return LabeledSwitchCell(
        label: "Enabled",
        isEnabled: source.isEnabled)
    }

    func makeNameValidator() -> InputValidator<String> {
      return InputValidator(
        syncValidation: { text in
          return !text.trimmed.isEmpty ? .Success(text) : .Failure(ValidationError.Empty)
        },
        validationCompletion: { [weak self] result in
          if let s = self {
            s.nameCell.highlightLabel(result.isFailure)
            s.refreshDoneButtonEnabled()
          }
        })
    }

    func makeVCardURLValidator() -> InputValidator<VCardSource.Connection> {
      return InputValidator(
        asyncValidation: { [weak self] connection in
          if let s = self {
            func cellsWithInvalidURLs(connection: VCardSource.Connection)
              -> [LabeledTextFieldCell]
            {
              var invalidURLCells: [LabeledTextFieldCell] = []
              if !connection.vcardURLasURL().isValidHTTPURL {
                invalidURLCells.append(s.vcardURLCell)
              }
              if let url = connection.loginURLasURL() where !url.isValidHTTPURL {
                invalidURLCells.append(s.loginURLCell)
              }
              return invalidURLCells
            }

            let invalidCells = cellsWithInvalidURLs(connection)
            guard invalidCells.isEmpty else {
              throw ValidationError.InvalidURLInput(invalidCells)
            }

            QueueExecution.async(QueueExecution.mainQueue) {
              s.vcardURLValidationResultView.start("Validating vCard URL…")
            }

            return s.urlDownloadFactory
                .makeDownloader(
                  connection: connection,
                  headers: Config.Net.VCardHTTPHeaders)
                .requestFileHeaders()
                .map { _ in connection }
          } else {
            return Future.failed(ValidationError.Cancelled)
          }
        },
        validationCompletion: { [weak self] result in
          if let s = self {
            switch result {
            case .Success:
              s.vcardURLCell.highlightLabel(false)
              s.loginURLCell.highlightLabel(false)
              s.vcardURLValidationResultView.stop("vCard URL is valid", fadeOut: true)
            case .Failure(let error):
              let validationResultText: String?
              switch error {
              case ValidationError.InvalidURLInput(let cells):
                for c in [s.vcardURLCell, s.loginURLCell] {
                  c.highlightLabel(cells.contains({ $0 === c }))
                }
                validationResultText = nil
              default:
                s.vcardURLCell.highlightLabel(false)
                s.loginURLCell.highlightLabel(false)
                validationResultText = (error as NSError).localizedDescription
              }
              s.vcardURLValidationResultView.stop(validationResultText)
            }
            s.refreshDoneButtonEnabled()
          }
        })
    }

    func setupBackgroundTapTo(view: UIView) {
      let tapRecognizer = UITapGestureRecognizer(target: self, action: "backgroundTapped:")
      tapRecognizer.cancelsTouchesInView = false
      view.addGestureRecognizer(tapRecognizer)
    }

    nameCell = makeNameCell()
    vcardURLCell = makeVCardURLCell()
    loginURLCell = makeLoginURLCell()
    authMethodCell = makeAuthMethodCell()
    usernameCell = makeUsernameCell()
    passwordCell = makePasswordCell()
    isEnabledCell = makeIsEnabledCell()

    nameValidator = makeNameValidator()
    vcardURLValidator = makeVCardURLValidator()

    cellsByIndexPath = makeCellsByIndexPath()

    noteLabel = MultilineLabel(
      frame: CGRect.zero,
      labelText: "Specify vCard file URL at remote server you trust. Prefer secure connections with https URLs. All contacts in the vCard file will be considered for importing.")

    vcardURLValidationResultView = LabeledActivityIndicator(frame: CGRect.zero)

    tableView = makeTableView()
    view = tableView

    setupBackgroundTapTo(view)
  }

  override func viewWillAppear(animated: Bool) {
    super.viewWillAppear(animated)

    if let previousSelection = tableView.indexPathForSelectedRow {
      tableView.deselectRowAtIndexPath(previousSelection, animated: true)
    }

    NSNotificationCenter.defaultCenter().addObserver(
      self,
      selector: "keyboardDidShow:",
      name: UIKeyboardDidShowNotification,
      object: nil)

    NSNotificationCenter.defaultCenter().addObserver(
      self,
      selector: "keyboardWillHide:",
      name: UIKeyboardWillHideNotification,
      object: nil)

    if isFirstTimeViewAppears {
      if isNewSource {
        refreshDoneButtonEnabled()
      } else {
        nameValidator.validate(nameCell.textFieldText)
        validateVCardURL()
      }
      isFirstTimeViewAppears = false
    }
  }

  override func viewWillDisappear(animated: Bool) {
    super.viewWillDisappear(animated)

    NSNotificationCenter.defaultCenter().removeObserver(self)

    if shouldCallOnSave {
      let authenticationMethod = authMethodCell.selection.data

      let newConnection = VCardSource.Connection(
        vcardURL: vcardURLCell.textFieldText,
        authenticationMethod: authenticationMethod,
        username: authenticationMethod == .None ? nil : usernameCell.textFieldText,
        password: authenticationMethod == .None ? nil : passwordCell.textFieldText,
        loginURL: authenticationMethod == .PostForm ? loginURLCell.textFieldText : nil)

      let newSource = source.with(
        name: nameCell.textFieldText.trimmed,
        connection: newConnection,
        isEnabled: isEnabledCell.switchOn)

      onSave(newSource)
    }
  }

  // MARK: UITableViewDelegate

  func tableView(
    tableView: UITableView,
    shouldHighlightRowAtIndexPath indexPath: NSIndexPath)
    -> Bool
  {
    return cellAtIndexPath(indexPath) === authMethodCell
  }

  func tableView(
    tableView: UITableView,
    heightForHeaderInSection section: Int)
    -> CGFloat
  {
    switch section {
    case 0, 1:
      return UITableViewAutomaticDimension
    default:
      return 20
    }
  }

  func tableView(
    tableView: UITableView,
    viewForHeaderInSection section: Int)
    -> UIView?
  {
    switch section {
    case 0:
      return noteLabel
    case 1:
      return vcardURLValidationResultView
    default:
      return nil
    }
  }

  func tableView(
    tableView: UITableView,
    didSelectRowAtIndexPath indexPath: NSIndexPath)
  {
    if let cell = cellAtIndexPath(indexPath) where cell === authMethodCell {
      let selectionOptions = HTTPRequest.AuthenticationMethod.allValues.map {
        SelectionOption(
          data: $0,
          shortDescription: $0.shortDescription,
          longDescription: $0.longDescription)
      }
      let previouslySelectedAuthMethod = authMethodCell.selection.data
      let preselectionIndex = selectionOptions.indexOf({ $0.data == previouslySelectedAuthMethod })!
      let vc = SelectionViewController(
        title: authMethodCell.labelText,
        selectionOptions: selectionOptions,
        preselectionIndex: preselectionIndex,
        selectionHandler: { [unowned self] selectedOption in
          let currentSelectedAuthMethod = selectedOption.data

          func showOrHideLoginURLCell() {
            let loginURLCellIndexPath = self.indexPathOfCell(self.loginURLCell)

            if currentSelectedAuthMethod == .PostForm {
              self.tableView.insertRowsAtIndexPaths([loginURLCellIndexPath], withRowAnimation: .Fade)
            } else if previouslySelectedAuthMethod == .PostForm {
              self.tableView.deleteRowsAtIndexPaths([loginURLCellIndexPath], withRowAnimation: .Fade)
            }
          }

          func showOrHideUsernameAndPasswordCells() {
            let indexPaths = [self.usernameCell, self.passwordCell].map { self.indexPathOfCell($0) }

            if currentSelectedAuthMethod == .None {
              self.tableView.deleteRowsAtIndexPaths(indexPaths, withRowAnimation: .Fade)
            } else if previouslySelectedAuthMethod == .None {
              self.tableView.insertRowsAtIndexPaths(indexPaths, withRowAnimation: .Fade)
            }
          }

          self.navigationController!.popViewControllerAnimated(true)

          if currentSelectedAuthMethod != previouslySelectedAuthMethod {
            self.authMethodCell.selection = selectedOption
            self.tableView.beginUpdates()
            showOrHideLoginURLCell()
            showOrHideUsernameAndPasswordCells()
            self.tableView.endUpdates()
            self.validateVCardURL(authenticationMethod: currentSelectedAuthMethod)
          }
        })
      navigationController!.pushViewController(vc, animated: true)
    }
  }

  // MARK: UITableViewDataSource

  func tableView(
    tableView: UITableView,
    cellForRowAtIndexPath indexPath: NSIndexPath)
    -> UITableViewCell
  {
    guard let cell = cellAtIndexPath(indexPath) else {
      fatalError("unknown indexpath: \(indexPath)")
    }
    return cell
  }

  func numberOfSectionsInTableView(tableView: UITableView) -> Int {
    return cellsByIndexPath.count
  }

  func tableView(
    tableView: UITableView,
    numberOfRowsInSection section: Int)
    -> Int
  {
    if let rows = cellsByIndexPath[section] {
      if section == 0 && authMethodCell.selection.data != .PostForm {
        return rows.count - 1
      }

      if section == 1 && authMethodCell.selection.data == .None {
        return rows.count - 2
      }

      return rows.count
    }
    fatalError("unknown section: \(section)")
  }

  // MARK: Actions

  func cancel(sender: AnyObject) {
    presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
  }

  func done(sender: AnyObject) {
    shouldCallOnSave = true
    presentingViewController?.dismissViewControllerAnimated(true, completion: nil)
  }

  // MARK: Notification Handlers

  func backgroundTapped(sender: AnyObject) {
    tableView.endEditing(true)
  }

  func keyboardDidShow(notification: NSNotification) {
    // adapted and modified from http://spin.atomicobject.com/2014/03/05/uiscrollview-autolayout-ios/

    func getKeyboardHeight() -> CGFloat? {
      if let rect = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.CGRectValue() {
        return rect.size.height
      }
      return nil
    }

    func coveredKeyboardHeightInViewFrame(keyboardHeight: CGFloat) -> CGFloat? {
      let frameInWindow = tableView.convertRect(tableView.bounds, toView: nil)

      if let window = tableView.window {
        let keyboardTopYCoord = window.bounds.size.height - keyboardHeight
        let viewBottomYCoord = frameInWindow.origin.y + frameInWindow.size.height
        return max(0, viewBottomYCoord - keyboardTopYCoord)
      }

      return nil
    }

    if let
      focusedTF = focusedTextField,
      keyboardHeight = getKeyboardHeight(),
      coveredKeyboardHeight = coveredKeyboardHeightInViewFrame(keyboardHeight)
    {
      let insets = UIEdgeInsets(
        top: topLayoutGuide.length,
        left: 0,
        bottom: coveredKeyboardHeight,
        right: 0)

      tableView.contentInset = insets
      tableView.scrollIndicatorInsets = insets

      if !CGRectContainsPoint(tableView.frame, focusedTF.frame.origin) {
        tableView.scrollRectToVisible(focusedTF.frame, animated: true)
      }
    }
  }

  func keyboardWillHide(notification: NSNotification) {
    let insets = UIEdgeInsets(
      top: topLayoutGuide.length,
      left: 0,
      bottom: bottomLayoutGuide.length,
      right: 0)
    tableView.contentInset = insets
    tableView.scrollIndicatorInsets = insets
  }

  // MARK: Helpers

  private func makeCellsByIndexPath() -> [Int: [Int: UITableViewCell]] {
    return [
      0: [
        0: nameCell,
        1: vcardURLCell,
        2: loginURLCell
      ],
      1: [
        0: authMethodCell,
        1: usernameCell,
        2: passwordCell
      ],
      2: [
        0: isEnabledCell
      ]
    ]
  }

  private func cellAtIndexPath(indexPath: NSIndexPath) -> UITableViewCell? {
    if let
      rows = cellsByIndexPath[indexPath.section],
      cell = rows[indexPath.row] {
        return cell
    }
    return nil
  }

  private func indexPathOfCell(cell: UITableViewCell) -> NSIndexPath {
    for (sectionNumber, sectionCells) in cellsByIndexPath {
      for (rowNumber, rowCell) in sectionCells {
        if cell === rowCell {
          return NSIndexPath(forRow: rowNumber, inSection: sectionNumber)
        }
      }
    }
    fatalError("No indexpath found for cell: \(cell)")
  }

  private func refreshDoneButtonEnabled() {
    if let button = navigationItem.rightBarButtonItem {
      button.enabled = (nameValidator.isValid ?? false) && (vcardURLValidator.isValid ?? false)
    }
  }

  private func validateVCardURL(
    vcardURL vcardURL: String? = nil,
    authenticationMethod: HTTPRequest.AuthenticationMethod? = nil,
    username: String? = nil,
    password: String? = nil,
    loginURL: String? = nil)
  {
    let authMethod = authenticationMethod ?? authMethodCell.selection.data

    let connection = VCardSource.Connection(
      vcardURL: vcardURL ?? vcardURLCell.textFieldText,
      authenticationMethod: authMethod,
      username: authMethod == .None ? nil : (username ?? usernameCell.textFieldText),
      password: authMethod == .None ? nil : (password ?? passwordCell.textFieldText),
      loginURL: loginURL ?? loginURLCell.textFieldText)

    vcardURLValidator.validate(connection)
  }
}
