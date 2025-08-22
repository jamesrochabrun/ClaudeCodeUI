import Combine
import LoggingServiceInterface
import TerminalServiceInterface
import XCTest
@testable import PermissionsService

// MARK: - DefaultPermissionsServiceTests

final class DefaultPermissionsServiceTests: XCTestCase {

  // MARK: Internal

  override func setUp() {
    loggingService = MockLoggingService()
    terminalService = MockTerminalService()
    userDefaults = UserDefaults()
  }

  override func tearDown() {
    loggingService = nil
    terminalService = nil
    cancellables.removeAll()
    userDefaults.removeObject(forKey: .xcodeExtensionPermissionHasBeenGrantedOnce)
  }

  @MainActor
  func test_isAccessibilityPermissionGrantedCurrentValuePublisher_sendsInitialValueToSubscriber() throws {
    let isAccessibilityPermissionGranted = false

    let subject = createPermissionService(isAccessibilityPermissionGrantedClosure: { isAccessibilityPermissionGranted })
    let exp = expectation(description: "sends initial value")
    let cancellable = subject.isAccessibilityPermissionGrantedCurrentValuePublisher.sink {
      XCTAssertFalse($0)
      exp.fulfill()
    }
    waitForExpectations(timeout: 1)
    _ = cancellable
  }

  @MainActor
  func test_isAccessibilityPermissionGrantedCurrentValuePublisher_accessIsGranted_updatesSubscriber() throws {
    var isAccessibilityPermissionGranted = false

    let subject = createPermissionService(isAccessibilityPermissionGrantedClosure: { isAccessibilityPermissionGranted })
    let exp = expectation(description: "sends two values")
    var counter = 0
    let cancellable = subject.isAccessibilityPermissionGrantedCurrentValuePublisher.sink {
      if counter == 0 {
        XCTAssertFalse($0)
      } else {
        XCTAssertTrue($0)
        exp.fulfill()
      }
      counter += 1
    }

    // Update the value and start polling.
    isAccessibilityPermissionGranted = true
    subject.monitorAccessibilityPermissionStatus()

    waitForExpectations(timeout: 1)
    _ = cancellable
  }

  /// Verifies that when `isAccessibilityPermissionGrantedCurrentValuePublisher` is accessed many times over (which can for example happen if it is accessed in a SwiftUI View body)
  /// there is a limited number of calls made to the AX API that doesn't increase with the number of accesses to the property.
  @MainActor
  func test_accessingManyTimes_isAccessibilityPermissionGrantedCurrentValuePublisher_doesntMakeNewAXCalls() throws {
    // We expect only two calls to the AX API (no more calls after the API has returned that the permission is granted)
    var callsCount = 0
    let isAccessibilityPermissionGrantedClosure = {
      callsCount += 1
      switch callsCount {
      case 1:
        // Initially the permission is not granted
        return false
      case 2:
        // Then it is granted
        return true
      default:
        // We only expect the closure to be called twice
        XCTFail("isAccessibilityPermissionGrantedClosure called too many times: \(callsCount)")
        return true
      }
    }

    let subject = createPermissionService(isAccessibilityPermissionGrantedClosure: isAccessibilityPermissionGrantedClosure)

    // Access the property a first time. This time we are getting two values (false, true).
    var exp = expectation(description: "Accessibility Permission is eventually granted")
    subject.isAccessibilityPermissionGrantedCurrentValuePublisher.sink { isGranted in
      if callsCount == 1 {
        XCTAssertFalse(isGranted)
      } else if isGranted {
        exp.fulfill()
      } else {
        XCTFail("isGranted is expected to be true after the first value")
      }
    }.store(in: &cancellables)
    waitForExpectations(timeout: 1)

    // Access the property a second time.
    // This time we are only getting the latest value (true). This doesn't make an API call to AX.
    exp = expectation(description: "Accessibility Permission is eventually granted")
    subject.isAccessibilityPermissionGrantedCurrentValuePublisher.sink { isGranted in
      if isGranted {
        exp.fulfill()
      }
    }.store(in: &cancellables)
    waitForExpectations(timeout: 1)

    // Access the property a third time to be sure. Same behavior as for the second time.
    exp = expectation(description: "Accessibility Permission is eventually granted")
    subject.isAccessibilityPermissionGrantedCurrentValuePublisher.sink { isGranted in
      if isGranted {
        exp.fulfill()
      }
    }.store(in: &cancellables)
    waitForExpectations(timeout: 1)
  }

  /// Verifies that when `isAccessibilityPermissionGrantedCurrentValuePublisher` is accessed many times over (which can for example happen if it is accessed in a SwiftUI View body)
  /// there is a limited number of calls made to the AX API that doesn't increase with the number of accesses to the property.
  @MainActor
  func test_discarding_isAccessibilityPermissionGrantedCurrentValuePublisher_beforePermissionIsGranted_letsOtherAccessToThePropertyReceiveNextValues(
  ) throws {
    var callsCount = 0
    let isAccessibilityPermissionGrantedClosure = {
      callsCount += 1
      switch callsCount {
      case 1:
        // Initially the permission is not granted
        return false
      default:
        // Then it is granted
        return true
      }
    }

    let subject = createPermissionService(isAccessibilityPermissionGrantedClosure: isAccessibilityPermissionGrantedClosure)

    // Access the property a first time.
    // We are not retaining the publisher / cancellable so the subscription will stop immediately before the permission is granted.
    var exp = expectation(description: "Accessibility Permission is eventually granted")
    _ = subject.isAccessibilityPermissionGrantedCurrentValuePublisher.sink { isGranted in
      guard !isGranted else {
        XCTFail(
          "isGranted is expected to be false as we are unsubscribing immediately (a first value is still received synchronously"
        )
        return
      }
      exp.fulfill()
    }
    waitForExpectations(timeout: 1)
    XCTAssertEqual(callsCount, 1)

    // Access the property a second time.
    // This time the permission has been granted. We verify that we are receiving the new value.
    exp = expectation(description: "Accessibility Permission is eventually granted")
    subject.isAccessibilityPermissionGrantedCurrentValuePublisher.sink { isGranted in
      if isGranted {
        exp.fulfill()
      }
    }.store(in: &cancellables)
    waitForExpectations(timeout: 1)
  }

  @MainActor
  func test_init_doesntCallIntoShell() throws {
    let invocations: [(_ input: String) -> String] = []
    _ = try terminalService.ensureAllInvocationsAreExecuted(invocations, whenExecuting: {
      createPermissionService()
    })
  }

  @MainActor
  func test_isXcodeExtensionPermissionGranted_callIntoShellWithTheExpectedArguments() throws {
    let permissionService = createPermissionService()

    let invocations: [(_ input: String) -> String] = [{ input in
      XCTAssertEqual(input, "ps aux | grep 'Xcode Assistant'")
      return """
        james_rochabrun       77201   0.0  0.0 410733264   1568 s000  S+    4:59PM   0:00.00 grep --color=auto XcodeAssistantExtension
        james_rochabrun       74705   0.0  0.0 410399056  12720   ??  Ss    4:33PM   0:00.03     /Users/me/Library/Developer/Xcode/DerivedData/XcodeAssistant-aphsccd../.../XcodeAssistantExtension -AppleLanguages ("en-US")
        """
    }]
    let isPermissionGranted = try terminalService.ensureAllInvocationsAreExecuted(invocations, whenExecuting: {
      try wait(for: permissionService.isXcodeExtensionPermissionGranted)
    })
    XCTAssertTrue(isPermissionGranted)
  }

  @MainActor
  func test_isXcodeExtensionPermissionGranted_setsPersistedValueAfterGranted() throws {
    let permissionService = createPermissionService()

    let invocations: [(_ input: String) -> String] = [{ input in
      XCTAssertEqual(input, "ps aux | grep 'Xcode Assistant'")
      return """
        james_rochabrun       77201   0.0  0.0 410733264   1568 s000  S+    4:59PM   0:00.00 grep --color=auto XcodeAssistantExtension
        james_rochabrun       74705   0.0  0.0 410399056  12720   ??  Ss    4:33PM   0:00.03     /Users/me/Library/Developer/Xcode/DerivedData/XcodeAssistant-aphsccd../.../XcodeAssistantExtension -AppleLanguages ("en-US")
        """
    }]
    _ = try terminalService.ensureAllInvocationsAreExecuted(invocations, whenExecuting: {
      try wait(for: permissionService.isXcodeExtensionPermissionGranted)
    })
    XCTAssertTrue(userDefaults.bool(forKey: .xcodeExtensionPermissionHasBeenGrantedOnce))
  }

  @MainActor
  func test_isXcodeExtensionPermissionGranted_returnedTrueIfAlreadyGranted_andDoesntCallIntoShell() throws {
    userDefaults.set(true, forKey: .xcodeExtensionPermissionHasBeenGrantedOnce)
    let permissionService = createPermissionService()

    let invocations: [(_ input: String) -> String] = []
    let isPermissionGranted = try terminalService.ensureAllInvocationsAreExecuted(invocations, whenExecuting: {
      try wait(for: permissionService.isXcodeExtensionPermissionGranted)
    })
    XCTAssertTrue(isPermissionGranted)
  }

  @MainActor
  func test_isXcodeExtensionPermissionGranted_doesntCallIntoShellSeveralTimesAtOnce() throws {
    let permissionService = createPermissionService()

    let invocations: [(_ input: String) -> String] = [{ input in
      XCTAssertEqual(input, "ps aux | grep 'Xcode Assistant'")
      return """
        james_rochabrun       77201   0.0  0.0 410733264   1568 s000  S+    4:59PM   0:00.00 grep --color=auto XcodeAssistantExtension
        james_rochabrun       74705   0.0  0.0 410399056  12720   ??  Ss    4:33PM   0:00.03     /Users/me/Library/Developer/Xcode/DerivedData/XcodeAssistant-aphsccd../.../XcodeAssistantExtension -AppleLanguages ("en-US")
        """
    }]
    let results = try terminalService.ensureAllInvocationsAreExecuted(invocations, whenExecuting: {
      // Call twice at the same time to read the permission
      let a = try wait(for: permissionService.isXcodeExtensionPermissionGranted)
      let b = try wait(for: permissionService.isXcodeExtensionPermissionGranted)

      return (a, b)
    })
    XCTAssertTrue(results.0)
    XCTAssertTrue(results.1)
  }

  @MainActor
  func skipped_test_isXcodeExtensionPermissionGranted_launchesXcodeIfItIsntRunning() throws {
    let permissionService = createPermissionService()

    let xcodePath = "/Applications/Xcode.app/Contents/Developer"
    let exp = expectation(description: "Xcode launched")

    let invocations: [(_ command: String) -> String] = [
      // XcodeAssistantExtension is not running
      { input in
        XCTAssertEqual(input, "ps aux | grep XcodeAssistantExtension")
        return ""
      },
      // Xcode is not running
      { input in
        XCTAssertEqual(input, "ps aux | grep Xcode")
        return ""
      },
      // Lookup where Xcode is installed
      { input in
        XCTAssertEqual(input, "xcode-select -p")
        return xcodePath
      },
      // Launch Xcode
      { input in
        XCTAssertEqual(input, "open /Applications/Xcode.app")
        exp.fulfill()
        return ""
      },
    ]

    try terminalService.ensureAllInvocationsAreExecuted(invocations, whenExecuting: {
      let isPermissionGranted = try wait(for: permissionService.isXcodeExtensionPermissionGranted)
      XCTAssertFalse(isPermissionGranted)
      waitForExpectations(timeout: 1)
    })
  }

  @MainActor
  func skipped_test_isXcodeExtensionPermissionGranted_doesntLaunchesXcodeIfItIsRunning() throws {
    let permissionService = createPermissionService()

    let exp = expectation(description: "Last command was invoked")
    let invocations: [(_ input: String) -> String] = [
      // XcodeAssistantExtension is not running
      { input in
        XCTAssertEqual(input, "ps aux | grep XcodeAssistantExtension")
        return ""
      },
      // Xcode is running
      { input in
        XCTAssertEqual(input, "ps aux | grep Xcode")
        exp.fulfill()
        return "james_rochabrun       74693  24.5  2.8 420613520 951504   ??  S     4:33PM   8:47.76 /Applications/Xcode-16.0.0.app/Contents/MacOS/Xcode"
      },
    ]
    try terminalService.ensureAllInvocationsAreExecuted(invocations, whenExecuting: {
      let isPermissionGranted = try wait(for: permissionService.isXcodeExtensionPermissionGranted)
      XCTAssertFalse(isPermissionGranted)
      waitForExpectations(timeout: 1)
    })
  }

  @MainActor
  func test_isXcodeExtensionPermissionGrantedCurrentValuePublisher_callIntoShellUntilTheExtensionIsRunning() throws {
    let permissionService = createPermissionService()

    var i = 0
    terminalService.onRunTerminalCommand = { input, _, _, _ in
      switch input {
      case "ps aux | grep Xcode":
        // In this scenario, Xcode is always running
        return TerminalResult(
          exitCode: 1,
          output: "james_rochabrun       74693  24.5  2.8 420613520 951504   ??  S     4:33PM   8:47.76 /Applications/Xcode-16.0.0.app/Contents/MacOS/Xcode"
        )

      case "ps aux | grep 'Xcode Assistant'":
        defer { i += 1 }
        if i == 0 {
          // Initially Xcode Extension permission is not granted
          return TerminalResult(exitCode: 1, output: "")
        } else {
          // Afterwards Xcode Extension permission has been not granted
          return TerminalResult(
            exitCode: 1,
            output: """
              james_rochabrun       77201   0.0  0.0 410733264   1568 s000  S+    4:59PM   0:00.00 grep --color=auto XcodeAssistantExtension
              james_rochabrun       74705   0.0  0.0 410399056  12720   ??  Ss    4:33PM   0:00.03     /Users/me/Library/Developer/Xcode/DerivedData/XcodeAssistant-aphsccd../.../XcodeAssistantExtension -AppleLanguages ("en-US")
              """
          )
        }

      default:
        throw MockTerminalService.UnexpectedCommandError(command: input)
      }
    }

    let exp = expectation(description: "Xcode Extension permission is granted")
    permissionService.isXcodeExtensionPermissionGrantedCurrentValuePublisher.sink { value in
      if value { exp.fulfill() }
    }.store(in: &cancellables)
    waitForExpectations(timeout: 1)
  }

  // MARK: Metrics

  @MainActor
  func test_accessibilityPermission_logsEventWhenGrantedForTheFirstTime() throws {
    let exp = expectation(description: "event recorded")
    loggingService.onLogEvent = { event, _, _ in
      XCTAssertEqual(event, "permissions.accessibilityPermissionGranted")
      exp.fulfill()
    }

    var i = 0
    let subject = createPermissionService(isAccessibilityPermissionGrantedClosure: {
      i += 1
      // Initially the permission is not granted (i == 1), then it is (i >= 2).
      return i == 2
    })
    subject.monitorAccessibilityPermissionStatus()

    waitForExpectations(timeout: 100)
  }

  @MainActor
  func test_accessibilityPermission_doesntLogEventWhenAlreadyGranted() async throws {
    let exp = expectation(description: "event recorded")
    loggingService.onLogEvent = { _, _, _ in
      XCTFail("No event should be logged")
      exp.fulfill()
    }
    Task.detached {
      // Waits 0.01s to make sure we are not logging an event.
      try await Task.sleep(nanoseconds: 10000000)
      exp.fulfill()
    }

    let subject = createPermissionService(isAccessibilityPermissionGrantedClosure: { true })
    subject.monitorAccessibilityPermissionStatus()

    await fulfillment(of: [exp])
  }

  @MainActor
  func test_xcodeExtensionPermission_logsEventWhenGrantedForTheFirstTime() throws {
    let exp = expectation(description: "event recorded")
    loggingService.onLogEvent = { event, _, _ in
      XCTAssertEqual(event, "permissions.xcodeExtensionPermissionGranted")
      exp.fulfill()
    }

    let subject = createPermissionService()

    let invocations: [(_ input: String) -> String] = [
      { input in
        XCTAssertEqual(input, "ps aux | grep 'Xcode Assistant'")
        return """
          james_rochabrun       77201   0.0  0.0 410733264   1568 s000  S+    4:59PM   0:00.00 grep --color=auto XcodeAssistantExtension
          james_rochabrun       74705   0.0  0.0 410399056  12720   ??  Ss    4:33PM   0:00.03     /Users/me/Library/Developer/Xcode/DerivedData/XcodeAssistant-aphsccd../.../XcodeAssistantExtension -AppleLanguages ("en-US")
          """
      },
    ]
    try terminalService.ensureAllInvocationsAreExecuted(invocations, whenExecuting: {
      subject.monitorXcodeExtensionPermissionStatus()
      waitForExpectations(timeout: 1)
    })
  }

  @MainActor
  func test_xcodeExtensionPermission_doesntLogEventWhenAlreadyGranted() async throws {
    let exp = expectation(description: "event recorded")
    loggingService.onLogEvent = { _, _, _ in
      XCTFail("No event should be logged")
      exp.fulfill()
    }
    Task.detached {
      // Waits 0.01s to make sure we are not logging an event.
      try await Task.sleep(nanoseconds: 10000000)
      exp.fulfill()
    }

    // Set the permission as already granted.
    userDefaults.set(true, forKey: .xcodeExtensionPermissionHasBeenGrantedOnce)
    let subject = createPermissionService()

    let invocations: [(_ input: String) -> String] = [
      { input in
        XCTAssertEqual(input, "ps aux | grep 'Xcode Assistant'")
        return """
          james_rochabrun       77201   0.0  0.0 410733264   1568 s000  S+    4:59PM   0:00.00 grep --color=auto XcodeAssistantExtension
          james_rochabrun       74705   0.0  0.0 410399056  12720   ??  Ss    4:33PM   0:00.03     /Users/me/Library/Developer/Xcode/DerivedData/XcodeAssistant-aphsccd../.../XcodeAssistantExtension -AppleLanguages ("en-US")
          """
      },
    ]
    try terminalService.ensureAllInvocationsAreExecuted(invocations, whenExecuting: {
      subject.monitorXcodeExtensionPermissionStatus()
      waitForExpectations(timeout: 1)
    })
  }

  // MARK: Private

  private var userDefaults: UserDefaults!

  private var loggingService: MockLoggingService!
  private var terminalService: MockTerminalService!

  private var cancellables = Set<AnyCancellable>()

  @MainActor
  private func createPermissionService(
    loggingService: LoggingService? = nil,
    terminalService: TerminalService? = nil,
    bundle: Bundle = .main,
    isAccessibilityPermissionGrantedClosure: @escaping () -> Bool = { true },
    pollIntervalNanoseconds: UInt64 = 100000000
  ) -> DefaultPermissionsService {
    .init(
      loggingService: loggingService ?? self.loggingService,
      terminalService: terminalService ?? self.terminalService,
      userDefaults: userDefaults,
      bundle: bundle,
      isAccessibilityPermissionGrantedClosure: isAccessibilityPermissionGrantedClosure,
      pollIntervalNanoseconds: pollIntervalNanoseconds
    )
  }

}

/// An extension to wait for async functions / calls within a test without making the context async.
extension XCTestCase {
  func wait<Value>(for future: Future<Value, Never>, timeout: TimeInterval = 1) throws -> Value {
    var result: Value?
    var error: Error?
    let exp = expectation(description: "Wait for future's value")

    let cancellable = future.sink(
      receiveCompletion: { completion in
        switch completion {
        case .finished:
          break
        case .failure(let encounteredError):
          error = encounteredError
        }
        exp.fulfill()
      },
      receiveValue: { value in
        result = value
      }
    )

    // Wait for the Future to complete
    wait(for: [exp], timeout: timeout)

    // Cancel the subscription to avoid memory leaks
    cancellable.cancel()

    if let error {
      throw error
    }
    if result == nil { }
    // If this is nil, this is because the expectation timeout
    return try XCTUnwrap(result)
  }
}
