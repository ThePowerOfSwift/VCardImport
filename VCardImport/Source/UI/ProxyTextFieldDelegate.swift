import UIKit

class ProxyTextFieldDelegate: NSObject, UITextFieldDelegate {
  typealias OnTextChangeCallback = (UITextField, String) -> Void

  private let onBeginEditing: UITextField -> Void
  private let onEndEditing: UITextField -> Void
  private let onShouldReturn: UITextField -> Bool
  private let onChange: OnTextChangeCallback?

  init(
    beginEditingHandler onBeginEditing: UITextField -> Void,
    endEditingHandler onEndEditing: UITextField -> Void,
    shouldReturnHandler onShouldReturn: UITextField -> Bool,
    changeHandler onChange: OnTextChangeCallback? = nil)
  {
    self.onBeginEditing = onBeginEditing
    self.onEndEditing = onEndEditing
    self.onShouldReturn = onShouldReturn
    self.onChange = onChange
  }

  // MARK: UITextFieldDelegate

  func textFieldDidBeginEditing(textField: UITextField) {
    onBeginEditing(textField)
  }

  func textFieldDidEndEditing(textField: UITextField) {
    onEndEditing(textField)
  }

  func textFieldShouldReturn(textField: UITextField) -> Bool {
    return onShouldReturn(textField)
  }

  func textFieldShouldClear(textField: UITextField) -> Bool {
    if let callback = onChange {
      callback(textField, "")
    }

    return true  // always allow clearing
  }

  func textField(
    textField: UITextField,
    shouldChangeCharactersInRange range: NSRange,
    replacementString string: String)
    -> Bool
  {
    func changedText(text: String) -> String {
      let unaffectedStart = (text as NSString).substringToIndex(range.location)
      let unaffectedEnd = (text as NSString).substringFromIndex(range.location + range.length)
      return unaffectedStart + string + unaffectedEnd
    }

    if let callback = onChange {
      callback(textField, changedText(textField.text!))
    }

    return true  // always allow text change
  }
}
