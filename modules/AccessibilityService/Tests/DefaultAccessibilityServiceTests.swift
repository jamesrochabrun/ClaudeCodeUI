import AppKit
import XCTest
@testable import AccessibilityService

/// Note: this doesn't test most functions in DefaultAccessibilityService
/// because AXUIElement properties cannot be easily set/mocked, which makes it impossible to test most of the methods.
final class DefaultAccessibilityServiceTests: XCTestCase {

  func testCaching() {
    // Create mock elements
    let element = AXUIElementCreateApplication(0)
    let result = AXUIElementCreateApplication(1)

    let sut = DefaultAccessibilityService()
    let exp = expectation(description: "function called")

    let result1 = sut.withCachedResult(
      element: element,
      cacheKey: "testKey"
    ) {
      // Without a cached value, this should be called.
      exp.fulfill()
      return [result]
    }
    XCTAssertEqual(result1.count, 1)
    XCTAssertEqual(result1.first, result)
    waitForExpectations(timeout: 1)

    // Now, the same call with the same cache key should return the cached value.
    let result2 = sut.withCachedResult(
      element: element,
      cacheKey: "testKey"
    ) {
      XCTFail("This should not be called.")
      return []
    }
    XCTAssertEqual(result2.count, 1)
    XCTAssertEqual(result2.first, result)
  }

}
