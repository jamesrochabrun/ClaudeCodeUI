import AppKit

extension AXUIElement {
  public var focusedElement: AXUIElement? {
    try? copyValue(key: kAXFocusedUIElementAttribute)
  }

  public var sharedFocusElements: [AXUIElement] {
    (try? copyValue(key: kAXChildrenAttribute)) ?? []
  }

  public var window: AXUIElement? {
    try? copyValue(key: kAXWindowAttribute)
  }

  public var windows: [AXUIElement] {
    (try? copyValue(key: kAXWindowsAttribute)) ?? []
  }

  public var isFullScreen: Bool {
    (try? copyValue(key: "AXFullScreen")) ?? false
  }

  public var focusedWindow: AXUIElement? {
    try? copyValue(key: kAXFocusedWindowAttribute)
  }

  public var topLevelElement: AXUIElement? {
    try? copyValue(key: kAXTopLevelUIElementAttribute)
  }

  public var rows: [AXUIElement] {
    (try? copyValue(key: kAXRowsAttribute)) ?? []
  }

  public var parent: AXUIElement? {
    try? copyValue(key: kAXParentAttribute)
  }

  public var children: [AXUIElement] {
    (try? copyValue(key: kAXChildrenAttribute)) ?? []
  }

  public var menuBar: AXUIElement? {
    try? copyValue(key: kAXMenuBarAttribute)
  }

  public var verticalScrollBar: AXUIElement? {
    try? copyValue(key: kAXVerticalScrollBarAttribute)
  }

}
