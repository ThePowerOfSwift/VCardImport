import Foundation

extension Array {
  typealias Predicate = T -> Bool

  func find(predicate: Predicate) -> T? {
    for e in self {
      if predicate(e) {
        return e
      }
    }
    return nil
  }

  func any(predicate: Predicate) -> Bool {
    return find(predicate) != nil
  }

  func partition(predicate: Predicate) -> ([T], [T]) {
    var applicables: [T] = []
    var nonApplicables:[T] = []

    for e in self {
      if predicate(e) {
        applicables.append(e)
      } else {
        nonApplicables.append(e)
      }
    }

    return (applicables, nonApplicables)
  }
}

extension Dictionary {
  var first: (Key, Value)? {
    var gen = self.generate()
    return gen.next()
  }

  func hasKey(key: Key) -> Bool {
    return self[key] != nil
  }

  func map<T: Hashable, U>(transform: (Key, Value) -> (T, U)) -> Dictionary<T, U> {
    var dict: [T: U] = [:]
    for oldKeyAndValue in self {
      let (key, value) = transform(oldKeyAndValue)
      dict[key] = value
    }
    return dict
  }
}

private let ISODateFormatter: NSDateFormatter = {
  let formatter = NSDateFormatter()
  formatter.timeZone = NSTimeZone(abbreviation: "GMT")
  formatter.dateFormat = "yyyy'-'MM'-'dd'T'HH':'mm':'ss'Z'"
  return formatter
}()

private let LocaleMediumDateFormatter: NSDateFormatter = {
  let formatter = NSDateFormatter()
  formatter.dateStyle = .MediumStyle
  formatter.timeStyle = .ShortStyle
  return formatter
}()

extension NSDate {
  var localeMediumString: NSString {
    return LocaleMediumDateFormatter.stringFromDate(self)
  }

  var ISOString: NSString {
    return ISODateFormatter.stringFromDate(self)
  }

  class func dateFromISOString(string: String) -> NSDate? {
    return ISODateFormatter.dateFromString(string)
  }
}

func ==<T: Equatable>(lhs: (T, T), rhs: (T, T)) -> Bool {
  return (lhs.0 == rhs.0) && (lhs.1 == rhs.1)
}

func !=<T: Equatable>(lhs: (T, T), rhs: (T, T)) -> Bool {
  return !(lhs == rhs)
}

func countWhere<S: SequenceType>(seq: S, predicate: (S.Generator.Element -> Bool)) -> Int {
  var c = 0
  for e in seq {
    if predicate(e) {
      c += 1
    }
  }
  return c
}

func mapDictionary<S: SequenceType, K: Hashable>(
  values: S,
  valueToKey: (Int, S.Generator.Element) -> K)
  -> [K: S.Generator.Element]
{
  var dict: [K: S.Generator.Element] = [:]
  for (index, value) in enumerate(values) {
    let key = valueToKey(index, value)
    dict[key] = value
  }
  return dict
}