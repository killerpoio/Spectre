#if os(Linux)
import Glibc
#else
import Darwin.C
import Foundation
#endif


enum ANSI : String, CustomStringConvertible {
  case Red = "\u{001B}[0;31m"
  case Green = "\u{001B}[0;32m"
  case Yellow = "\u{001B}[0;33m"

  case Bold = "\u{001B}[0;1m"
  case Reset = "\u{001B}[0;0m"

  var description:String {
    if isatty(STDOUT_FILENO) > 0 {
      return rawValue
    }

    return ""
  }
}


struct CaseFailure {
  let position: [String]
  let failure: FailureType

  init(position: [String], failure: FailureType) {
    self.position = position
    self.failure = failure
  }
}


func printFailures(failures: [CaseFailure]) {
  for failure in failures {
    let name = failure.position.joined(separator: " ")
    Swift.print(ANSI.Red, name)
    let file = "\(failure.failure.file):\(failure.failure.line)"
    Swift.print("  \(ANSI.Bold)\(file)\(ANSI.Reset) \(ANSI.Yellow)\(failure.failure.reason)\(ANSI.Reset)\n")

#if !os(Linux)
#if swift(>=3.0)
// TODO
#else
    if let contents = try? NSString(contentsOfFile: failure.failure.file, encoding: NSUTF8StringEncoding) as String {
      let lines = contents.componentsSeparatedByCharactersInSet(NSCharacterSet.newlineCharacterSet())
      let line = lines[failure.failure.line - 1]
      let trimmedLine = line.stringByTrimmingCharactersInSet(NSCharacterSet.whitespaceCharacterSet())
      Swift.print("  ```")
      Swift.print("  \(trimmedLine)")
      Swift.print("  ```")
    }
#endif
#endif
  }
}


class CountReporter : Reporter, ContextReporter {
  var depth = 0
  var successes = 0
  var disabled = 0
  var position = [String]()
  var failures = [CaseFailure]()

  func printStatus() {
    printFailures(failures)

    let disabledMessage: String
    if disabled > 0 {
      disabledMessage = " \(disabled) skipped,"
    } else {
      disabledMessage = ""
    }

    if failures.count == 1 {
      print("\(successes) passes\(disabledMessage) and \(failures.count) failure")
    } else {
      print("\(successes) passes\(disabledMessage) and \(failures.count) failures")
    }
  }

#if swift(>=3.0)
  func report(closure: @noescape (ContextReporter) -> Void) -> Bool {
    closure(self)
    printStatus()
    return failures.isEmpty
  }
#else
  func report(@noescape closure: (ContextReporter) -> Void) -> Bool {
    closure(self)
    printStatus()
    return failures.isEmpty
  }
#endif

#if swift(>=3.0)
  func report(_ name: String, closure: @noescape (ContextReporter) -> Void) {
    depth += 1
    position.append(name)
    closure(self)
    depth -= 1
    position.removeLast()
  }
#else
  func report(_ name: String, @noescape closure: (ContextReporter) -> Void) {
    depth += 1
    position.append(name)
    closure(self)
    depth -= 1
    position.removeLast()
  }
#endif

  func addSuccess(_ name: String) {
    successes += 1
  }

  func addDisabled(_ name: String) {
    disabled += 1
  }

  func addFailure(_ name: String, failure: FailureType) {
    failures.append(CaseFailure(position: position + [name], failure: failure))
  }
}


/// Standard reporter
class StandardReporter : CountReporter {
#if swift(>=3.0)
  override func report(_ name: String, closure: @noescape (ContextReporter) -> Void) {
    colour(.Bold, "-> \(name)")
    super.report(name, closure: closure)
    print("")
  }
#else
  override func report(_ name: String, @noescape closure: (ContextReporter) -> Void) {
    colour(.Bold, "-> \(name)")
    super.report(name, closure: closure)
    print("")
  }
#endif

  override func addSuccess(_ name: String) {
    super.addSuccess(name)
    colour(.Green, "-> \(name)")
  }

  override func addDisabled(_ name: String) {
    super.addDisabled(name)
    colour(.Yellow, "-> \(name)")
  }

  override func addFailure(_ name: String, failure: FailureType) {
    super.addFailure(name, failure: failure)
    colour(.Red, "-> \(name)")
  }

  func colour(_ colour: ANSI, _ message: String) {
#if swift(>=3.0)
    let indentation = String(repeating: " " as Character, count: depth * 2)
#else
    let indentation = String(count: depth * 2, repeatedValue: " " as Character)
#endif
    print("\(indentation)\(colour)\(message)\(ANSI.Reset)")
  }
}


/// Simple reporter that outputs minimal . F and S.
class DotReporter : CountReporter {
  override func addSuccess(_ name: String) {
    super.addSuccess(name)
    print(ANSI.Green, ".", ANSI.Reset, separator: "", terminator: "")
  }

  override func addDisabled(_ name: String) {
    super.addDisabled(name)
    print(ANSI.Yellow, "S", ANSI.Reset, separator: "", terminator: "")
  }

  override func addFailure(_ name: String, failure: FailureType) {
    super.addFailure(name, failure: failure)
    print(ANSI.Red, "F", ANSI.Reset, separator: "", terminator: "")
  }

  override func printStatus() {
    print("\n")
    super.printStatus()
  }
}


/// Test Anything Protocol compatible reporter
/// http://testanything.org
class TapReporter : CountReporter {
  var count = 0

  override func addSuccess(_ name: String) {
    count += 1
    super.addSuccess(name)

    let message = (position + [name]).joined(separator: " ")
    print("ok \(count) - \(message)")
  }

  override func addDisabled(_ name: String) {
    count += 1
    super.addDisabled(name)

    let message = (position + [name]).joined(separator: " ")
    print("ok \(count) - # skip \(message)")
  }

  override func addFailure(_ name: String, failure: FailureType) {
    count += 1
    super.addFailure(name, failure: failure)

    let message = (position + [name]).joined(separator: " ")
    print("not ok \(count) - \(message)")
    print("# \(failure.reason) from \(failure.file):\(failure.line)")
  }

  override func printStatus() {
    print("\(min(1, count))..\(count)")
  }
}
