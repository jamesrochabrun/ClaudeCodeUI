
import AppKit

#if DEBUG
public final class MockAccessibilityService: AccessibilityService {

  // MARK: Lifecycle

  public init() { }

  // MARK: Public

  public var childrenStub: ((AXUIElement, (AXUIElement) -> Bool, (AXUIElement) -> Bool) -> [AXUIElement])?

  public var firstParentStub: ((AXUIElement, (AXUIElement) -> Bool, String?) -> AXUIElement?)?

  public var firstChildStub: ((AXUIElement, (AXUIElement) -> Bool, (AXUIElement) -> Bool, String?) -> AXUIElement?)?

  public var cacheStub: ((AXUIElement, [AXUIElement], String) -> Void)?

  public var cachedValueStub: ((AXUIElement, String) -> [AXUIElement]?)?

  public var withCachedResultStub: ((AXUIElement, String?, () throws -> [AXUIElement]) -> [AXUIElement])?

  // MARK: - Public Methods

  public func children(
    from element: AXUIElement,
    where match: (AXUIElement) -> Bool,
    skipDescendants: (AXUIElement) -> Bool
  ) -> [AXUIElement] {
    childrenStub?(element, match, skipDescendants) ?? []
  }

  public func firstParent(
    from element: AXUIElement,
    where match: (AXUIElement) -> Bool,
    cacheKey: String?
  ) -> AXUIElement? {
    firstParentStub?(element, match, cacheKey)
  }

  public func firstChild(
    from element: AXUIElement,
    where match: (AXUIElement) -> Bool,
    skipDescendants: (AXUIElement) -> Bool,
    cacheKey: String?
  ) -> AXUIElement? {
    firstChildStub?(element, match, skipDescendants, cacheKey)
  }

  public func withCachedResult(element: AXUIElement, cacheKey: String?, _ block: () -> [AXUIElement]) -> [AXUIElement] {
    withCachedResultStub?(element, cacheKey, block) ?? []
  }

  public func clearCache() {
    // Mock implementation - no-op
  }
}
#endif
