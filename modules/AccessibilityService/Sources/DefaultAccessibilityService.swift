import AccessibilityFoundation
import AccessibilityServiceInterface
import AppKit
import os

// MARK: - DefaultAccessibilityService

public final class DefaultAccessibilityService: AccessibilityService {

  // MARK: Lifecycle

  public init() {
    lock = OSAllocatedUnfairLock(uncheckedState: cachedElements)
  }

  // MARK: Public

  public func children(
    from element: AXUIElement,
    where match: (AXUIElement) -> Bool,
    skipDescendants: (AXUIElement) -> Bool
  ) -> [AXUIElement] {
    withCachedResult(element: element, cacheKey: nil) {
      traverseTree(
        root: element,
        getChildren: { $0.children.filter { !skipDescendants($0) } },
        visitNode: { node, acc in
          if match(node) {
            acc.append(node)
            return .skipDescendants
          }
          return .continue
        }
      )
    }
  }

  public func firstParent(from element: AXUIElement, where match: (AXUIElement) -> Bool, cacheKey: String?) -> AXUIElement? {
    guard let parent = element.parent else { return nil }
    return withCachedResult(element: element, cacheKey: cacheKey) {
      traverseTree(
        root: parent,
        getChildren: { $0.parent.map { [$0] } ?? [] },
        visitNode: { node, acc in
          if match(node) {
            acc.append(node)
            return .skipDescendants
          }
          return .continue
        }
      )
    }.first
  }

  public func firstChild(
    from element: AXUIElement,
    where match: (AXUIElement) -> Bool,
    skipDescendants: (AXUIElement) -> Bool,
    cacheKey: String?
  ) -> AXUIElement? {
    withCachedResult(element: element, cacheKey: cacheKey) {
      traverseTree(
        root: element,
        getChildren: { $0.children },
        visitNode: { node, acc in
          if match(node) {
            acc.append(node)
            return .stop
          } else if skipDescendants(node) {
            return .skipDescendants
          }
          return .continue
        }
      )
    }.first
  }

  public func withCachedResult(
    element: AXUIElement,
    cacheKey: String?,
    _ block: () -> [AXUIElement]
  ) -> [AXUIElement] {
    if let cacheKey {
      let cachedElement = lock.withLock { $0[element] }
      if let els = cachedElement?[cacheKey] {
        if els.allSatisfy { $0.isValid } {
          return els
        }
      }
    }

    let value = block()
    if let cacheKey {
      cache(element: element, value: value, key: cacheKey)
    }
    return value
  }

  // MARK: Private

  private var cachedElements = [AXUIElement: [String: [AXUIElement]]]()

  private let lock: OSAllocatedUnfairLock<[AXUIElement: [String: [AXUIElement]]]>

  private func cache(element: AXUIElement, value: [AXUIElement], key: String) {
    lock.withLock { cachedElements in
      cachedElements[element] = cachedElements[element] ?? [:]
      cachedElements[element]?[key] = value
    }
  }

}
