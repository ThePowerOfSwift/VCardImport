import MiniFuture

class InputValidator<T> {
  private var validationDebouncer: (T -> Void)!
  private var isLastValidationSuccess: Bool?

  init(
    asyncValidation inputValidator: T throws -> Future<T>,
    validationCompletion onValidated: Try<T> -> Void,
    queueTo onValidatedQueue: QueueExecution.Queue = QueueExecution.mainQueue)
  {
    func validate(input: T) -> Future<T> {
      do {
        return try inputValidator(input)
      } catch {
        return Future.failed(error)
      }
    }

    let queue = QueueExecution.makeSerialQueue("InputValidator")
    let switcher = Future<T>.makeSwitchLatest()

    validationDebouncer = QueueExecution.makeDebouncer(Config.UI.ValidationThrottleInMS, queue) { [weak self] input in
      // validator still exists, makes sense to validate?
      if self != nil {
        // never call Future#get here as switcher completes only the latest Future
        switcher(validate(input)).onComplete { result in
          // validator still exists, makes sense to pass validation result?
          if let s = self {
            s.isLastValidationSuccess = result.isSuccess
            QueueExecution.async(onValidatedQueue) { onValidated(result) }
          }
        }
      }
    }
  }

  convenience init(
    syncValidation textValidator: T throws -> Try<T>,
    validationCompletion onValidated: Try<T> -> Void,
    queueTo onValidatedQueue: QueueExecution.Queue = QueueExecution.mainQueue)
  {
    self.init(
      asyncValidation: { Future.fromTry(try textValidator($0)) },
      validationCompletion: onValidated,
      queueTo: onValidatedQueue)
  }

  var isValid: Bool? {
    return isLastValidationSuccess
  }

  func validate(input: T) {
    validationDebouncer(input)
  }
}