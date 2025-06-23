import AppKit
import XCTest
@testable import AccessibilityServiceInterface

final class MockAccessibilityServiceTests: XCTestCase {

  // MARK: Internal

  // MARK: - Setup

  override func setUp() {
    super.setUp()
    service = MockAccessibilityService()
    element = AXUIElementCreateApplication(0) // Create a mock element
  }

  // MARK: - Tests

  func testChildrenStub() {
    // Given
    let expectedElements: [AXUIElement] = [element]
    service.childrenStub = { el, _, _ in
      // Verify parameters are passed correctly
      XCTAssertEqual(el, self.element)
      return expectedElements
    }

    // When
    let result = service.children(
      from: element,
      where: { _ in true },
      skipDescendants: { _ in false }
    )

    // Then
    XCTAssertEqual(result, expectedElements)
  }

  func testFirstParentStub() {
    // Given
    let expectedElement = element
    service.firstParentStub = { el, _, _ in
      // Verify parameters are passed correctly
      XCTAssertEqual(el, self.element)
      return expectedElement
    }

    // When
    let result = service.firstParent(
      from: element,
      where: { _ in true },
      cacheKey: nil
    )

    // Then
    XCTAssertEqual(result, expectedElement)
  }

  func testFirstChildStub() {
    // Given
    let expectedElement = element
    let cacheKey = "key"
    service.firstChildStub = { el, _, _, key in
      // Verify parameters are passed correctly
      XCTAssertEqual(el, self.element)
      XCTAssertEqual(key, cacheKey)
      return expectedElement
    }

    // When
    let result = service.firstChild(
      from: element,
      where: { _ in true },
      skipDescendants: { _ in false },
      cacheKey: cacheKey
    )

    // Then
    XCTAssertEqual(result, expectedElement)
  }

  func testWithCachedResultStub() {
    // Given
    let expectedElements: [AXUIElement] = [element]
    let cacheKey = "key"
    service.withCachedResultStub = { el, key, _ in
      // Verify parameters are passed correctly
      XCTAssertEqual(el, self.element)
      XCTAssertEqual(key, cacheKey)
      return expectedElements
    }

    // When
    let result = service.withCachedResult(
      element: element,
      cacheKey: cacheKey
    ) { [] }

    // Then
    XCTAssertEqual(result, expectedElements)
  }

  func testDefaultValuesWhenStubsNotSet() {
    // Given
    service.childrenStub = nil
    service.firstParentStub = nil
    service.firstChildStub = nil
    service.withCachedResultStub = nil

    // When & Then
    XCTAssertEqual(
      service.children(from: element, where: { _ in true }, skipDescendants: { _ in false }),
      []
    )
    XCTAssertNil(
      service.firstParent(from: element, where: { _ in true }, cacheKey: nil)
    )
    XCTAssertNil(
      service.firstChild(from: element, where: { _ in true }, skipDescendants: { _ in false }, cacheKey: nil)
    )
    XCTAssertEqual(
      service.withCachedResult(element: element, cacheKey: nil) { [] },
      []
    )
  }

  // MARK: Private

  private var service: MockAccessibilityService!
  private var element: AXUIElement!

}
