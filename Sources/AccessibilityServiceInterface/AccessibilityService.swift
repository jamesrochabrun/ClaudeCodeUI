
import AppKit

// MARK: - AccessibilityService

public protocol AccessibilityService {

  /// - Parameters:
  ///   - element: The element whose children are returned.
  ///   - match: Whether the element is the one to return.
  ///   - skipDescendants: Whether the element should be skipped. If true, its descendants are skipped.
  /// - Returns: All the children that match the given condition.
  ///  Note: if an element is matched, its descendants are not returned.
  func children(
    from element: AXUIElement,
    where match: (AXUIElement) -> Bool,
    skipDescendants: (AXUIElement) -> Bool
  ) -> [AXUIElement]

  /// - Parameters:
  ///   - element: The element whose parent is returned.
  ///   - match: Whether the element is the one to return.
  ///   - cacheKey: The cache key use to avoid recomputing the value.  If `nil` no caching is done.
  /// - Returns: The first parent that matches the given condition.
  func firstParent(
    from element: AXUIElement,
    where match: (AXUIElement) -> Bool,
    cacheKey: String?
  ) -> AXUIElement?

  /// - Parameters:
  ///   - element: The element whose child is returned.
  ///   - match: Whether the element is the one to return.
  ///   - skipDescendants: Whether the element should be skipped. If true, its descendants are skipped.
  ///   - cacheKey: The cache key use to avoid recomputing the value.  If `nil` no caching is done.
  /// - Returns: The first child that matches the given condition.
  func firstChild(
    from element: AXUIElement,
    where match: (AXUIElement) -> Bool,
    skipDescendants: (AXUIElement) -> Bool,
    cacheKey: String?
  ) -> AXUIElement?

  /// Return the cached value if it exists, otherwise compute the value and cache it.
  /// - Parameters:
  ///   - element: The element associated with the cache key.
  ///   - cacheKey: The cache key use to avoid recomputing the value.  If `nil` no caching is done.
  ///   - block: How to compute the result if it is not cached.
  func withCachedResult(
    element: AXUIElement,
    cacheKey: String?,
    _ block: () -> [AXUIElement]
  ) -> [AXUIElement]

  /// Clears all cached accessibility elements.
  /// Useful when restarting observation to ensure fresh data.
  func clearCache()

}

// MARK: - AccessibilityService + default values
extension AccessibilityService {

  /// - Parameters:
  ///   - element: The element whose children are returned.
  ///   - match: Whether the element is the one to return.
  /// - Returns: All the children that match the given condition.
  ///  Note: if an element is matched, its descendants are not returned.
  public func children(
    from element: AXUIElement,
    where match: (AXUIElement) -> Bool
  ) -> [AXUIElement] {
    children(from: element, where: match, skipDescendants: { _ in false })
  }

  /// - Parameters:
  ///   - element: The element whose child is returned.
  ///   - match: Whether the element is the one to return.
  ///   - cacheKey: The cache key use to avoid recomputing the value.  If `nil` no caching is done.
  /// - Returns: The first child that matches the given condition.
  public func firstChild(
    from element: AXUIElement,
    where match: (AXUIElement) -> Bool,
    cacheKey: String?
  ) -> AXUIElement? {
    firstChild(from: element, where: match, skipDescendants: { _ in false }, cacheKey: cacheKey)
  }
}

// MARK: - AccessibilityServiceProviding

public protocol AccessibilityServiceProviding {
  var accessibilityService: AccessibilityService { get }
}

// MARK: AXUIElement + AccessibilityService
extension AXUIElement {

  public func children(
    accessibilityService: AccessibilityService,
    where match: (AXUIElement) -> Bool,
    skipDescendants: (AXUIElement) -> Bool = { _ in false }
  ) -> [AXUIElement] {
    accessibilityService.children(from: self, where: match, skipDescendants: skipDescendants)
  }

  public func firstParent(
    accessibilityService: AccessibilityService,
    where match: (AXUIElement) -> Bool,
    cacheKey: String?
  ) -> AXUIElement? {
    accessibilityService.firstParent(from: self, where: match, cacheKey: cacheKey)
  }

  public func firstChild(
    accessibilityService: AccessibilityService,
    where match: (AXUIElement) -> Bool,
    skipDescendants: (AXUIElement) -> Bool,
    cacheKey: String?
  ) -> AXUIElement? {
    accessibilityService.firstChild(
      from: self,
      where: match,
      skipDescendants: skipDescendants,
      cacheKey: cacheKey
    )
  }
}
