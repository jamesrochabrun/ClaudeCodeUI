import XCTest
@testable import AccessibilityFoundation

final class AXGatedStateTests: XCTestCase {
  func test_knownState() {
    XCTAssertNil(AXGatedState<Bool>.initializing.knownState)

    XCTAssertNil(AXGatedState<Bool>.unknownDueToMissingAccessibilityPermissions.knownState)

    XCTAssertEqual(AXGatedState<Bool>.known(true).knownState, true)
  }
}
