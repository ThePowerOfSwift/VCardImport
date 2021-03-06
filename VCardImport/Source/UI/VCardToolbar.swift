import UIKit

private func makeEffectView() -> UIVisualEffectView {
  let blurEffect = UIBlurEffect(style: .Light)
  return UIVisualEffectView(effect: blurEffect)
}

private func makeButton(
  title: String,
  align labelAlignment: UIControlContentHorizontalAlignment)
  -> UIButton
{
  let button = UIButton(type: .System)
  button.setTitle(title, forState: .Normal)
  if let label = button.titleLabel {
    label.font = UIFont.fontForBodyStyle().fontWithSize(17)
  }
  button.contentHorizontalAlignment = labelAlignment
  return button
}

private func makeProgressLabel() -> UILabel {
  let label = UILabel()
  label.textAlignment = .Center
  label.textColor = Config.UI.ToolbarProgressTextColor
  label.adjustsFontSizeToFitWidth = true
  label.font = UIFont.fontForBodyStyle().fontWithSize(13)
  label.minimumScaleFactor = 0.85
  label.lineBreakMode = .ByWordWrapping
  label.numberOfLines = 2
  label.alpha = 0
  return label
}

private func makeProgressView() -> UIProgressView {
  let view = UIProgressView(progressViewStyle: .Bar)
  view.alpha = 0
  return view
}

private func makeBorderLayer() -> CALayer {
  let layer = CALayer()
  layer.backgroundColor = Config.UI.ToolbarBorderColor
  return layer
}

private func getBorderLayerRect(width: CGFloat) -> CGRect {
  return CGRect(x: 0, y: 0, width: width, height: 1)
}

class VCardToolbar: UIView {
  typealias ImportHandler = () -> Void

  private let effectView = makeEffectView()
  private let importButton = makeButton("Import", align: .Left)
  private let backupButton = makeButton("Backup", align: .Right)
  private let progressLabel = makeProgressLabel()
  private let progressView = makeProgressView()

  private let importHandler: ImportHandler

  private var border: CALayer!

  init(importHandler: ImportHandler) {
    self.importHandler = importHandler

    super.init(frame: CGRect.zero)

    border = makeBorderLayer()

    addSubview(effectView)
    addSubview(importButton)
    addSubview(backupButton)
    addSubview(progressLabel)

    // add border sublayer before progressView so that the latter obscures the
    // former when shown
    layer.addSublayer(border)
    addSubview(progressView)

    backgroundColor = Config.UI.ToolbarBackgroundColor

    setupLayout()

    importButton.addTarget(
      self,
      action: #selector(VCardToolbar.onTapImportButton(_:)),
      forControlEvents: .TouchUpInside)

    backupButton.hidden = true  // not implemented yet
  }

  required init?(coder decoder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  var importButtonEnabled: Bool {
    get {
      return importButton.enabled
    }
    set {
      importButton.enabled = newValue
    }
  }

  func beginProgress(text: String) {
    progressLabel.text = text
    progressView.setProgress(0, animated: false)

    UIView.animateWithDuration(
      Config.UI.MessageFadeAnimationDuration,
      delay: 0,
      options: .CurveEaseIn,
      animations: { [unowned self] in
        self.progressLabel.alpha = 1
        self.progressView.alpha = 1
      },
      completion: nil)
  }

  func endProgress() {
    UIView.animateWithDuration(
      Config.UI.MessageFadeAnimationDuration,
      delay: Config.UI.MessageFadeOutAnimationDelay,
      options: .CurveEaseOut,
      animations: { [unowned self] in
        self.progressLabel.alpha = 0
        self.progressView.alpha = 0
      },
      completion: { [unowned self] _ in
        self.progressLabel.text = nil
        self.progressView.setProgress(0, animated: false)
      })
  }

  func inProgress(text text: String, progress: Float) {
    progressLabel.text = text
    progressView.setProgress(progress, animated: true)
  }

  override func layoutSubviews() {
    super.layoutSubviews()
    border.frame = getBorderLayerRect(bounds.size.width)
  }

  // MARK: Actions

  func onTapImportButton(sender: AnyObject) {
    importHandler()
  }

  // MARK: Helpers

  private func setupLayout() {
    effectView.translatesAutoresizingMaskIntoConstraints = false
    importButton.translatesAutoresizingMaskIntoConstraints = false
    importButton.setContentHuggingPriority(251, forAxis: .Horizontal)
    backupButton.translatesAutoresizingMaskIntoConstraints = false
    backupButton.setContentHuggingPriority(251, forAxis: .Horizontal)
    progressLabel.translatesAutoresizingMaskIntoConstraints = false
    progressLabel.setContentCompressionResistancePriority(749, forAxis: .Horizontal)
    progressView.translatesAutoresizingMaskIntoConstraints = false

    let effectViewToObject = ["effect": effectView]

    NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat(
      "H:|[effect]|",
      options: [],
      metrics: nil,
      views: effectViewToObject))

    NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat(
      "V:|[effect]|",
      options: [],
      metrics: nil,
      views: effectViewToObject))

    NSLayoutConstraint(
      item: importButton,
      attribute: .CenterY,
      relatedBy: .Equal,
      toItem: self,
      attribute: .CenterY,
      multiplier: 1,
      constant: 0).active = true

    NSLayoutConstraint(
      item: backupButton,
      attribute: .CenterY,
      relatedBy: .Equal,
      toItem: self,
      attribute: .CenterY,
      multiplier: 1,
      constant: 0).active = true

    NSLayoutConstraint(
      item: importButton,
      attribute: .Width,
      relatedBy: .Equal,
      toItem: backupButton,
      attribute: .Width,
      multiplier: 1,
      constant: 0).active = true

    NSLayoutConstraint(
      item: progressLabel,
      attribute: .CenterY,
      relatedBy: .Equal,
      toItem: self,
      attribute: .CenterY,
      multiplier: 1,
      constant: 0).active = true

    NSLayoutConstraint(
      item: progressView,
      attribute: .Width,
      relatedBy: .Equal,
      toItem: self,
      attribute: .Width,
      multiplier: 1,
      constant: 0).active = true

    NSLayoutConstraint(
      item: progressView,
      attribute: .Top,
      relatedBy: .Equal,
      toItem: self,
      attribute: .Top,
      multiplier: 1,
      constant: 0).active = true

    NSLayoutConstraint(
      item: progressView,
      attribute: .Height,
      relatedBy: .Equal,
      toItem: nil,
      attribute: .NotAnAttribute,
      multiplier: 1,
      constant: 4).active = true

    NSLayoutConstraint.activateConstraints(NSLayoutConstraint.constraintsWithVisualFormat(
      "H:|-[importButton(>=50)]-10-[progressLabel]-10-[backupButton(>=50)]-|",
      options: [],
      metrics: nil,
      views: [
        "importButton": importButton,
        "backupButton": backupButton,
        "progressLabel": progressLabel
      ]))
  }
}
