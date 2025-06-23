import AppKit

// MARK: - AXNotification

/// A notification from an accessibility.
public struct AXNotification<State: Sendable>: Sendable {
  /// The type of notification that was triggered.
  public var kind: AXNotificationKind
  /// The element related to the notification.
  public var element: AXUIElement
  /// The state after the notification's effect was applied.
  public var state: State?

  public init(kind: AXNotificationKind, element: AXUIElement, state: State? = nil) {
    self.kind = kind
    self.element = element
    self.state = state
  }
}

// MARK: - AXNotificationKind

public enum AXNotificationKind: String, Sendable {
  case mainWindowChanged = "AXMainWindowChanged" // kAXMainWindowChangedNotification
  case focusedWindowChanged = "AXFocusedWindowChanged" // kAXFocusedWindowChangedNotification
  case focusedUIElementChanged = "AXFocusedUIElementChanged" // kAXFocusedUIElementChangedNotification
  case applicationActivated = "AXApplicationActivated" // kAXApplicationActivatedNotification
  case applicationDeactivated = "AXApplicationDeactivated" // kAXApplicationDeactivatedNotification
  case applicationHidden = "AXApplicationHidden" // kAXApplicationHiddenNotification
  case applicationShown = "AXApplicationShown" // kAXApplicationShownNotification
  case windowCreated = "AXWindowCreated" // kAXWindowCreatedNotification
  case windowMoved = "AXWindowMoved" // kAXWindowMovedNotification
  case windowResized = "AXWindowResized" // kAXWindowResizedNotification
  case windowMiniaturized = "AXWindowMiniaturized" // kAXWindowMiniaturizedNotification
  case windowDeminiaturized = "AXWindowDeminiaturized" // kAXWindowDeminiaturizedNotification
  case drawerCreated = "AXDrawerCreated" // kAXDrawerCreatedNotification
  case sheetCreated = "AXSheetCreated" // kAXSheetCreatedNotification
  case helpTagCreated = "AXHelpTagCreated" // kAXHelpTagCreatedNotification
  case valueChanged = "AXValueChanged" // kAXValueChangedNotification
  case uiElementDestroyed = "AXUIElementDestroyed" // kAXUIElementDestroyedNotification
  case elementBusyChanged = "AXElementBusyChanged" // kAXElementBusyChangedNotification
  case menuOpened = "AXMenuOpened" // kAXMenuOpenedNotification
  case menuClosed = "AXMenuClosed" // kAXMenuClosedNotification
  case menuItemSelected = "AXMenuItemSelected" // kAXMenuItemSelectedNotification
  case rowCountChanged = "AXRowCountChanged" // kAXRowCountChangedNotification
  case rowExpanded = "AXRowExpanded" // kAXRowExpandedNotification
  case rowCollapsed = "AXRowCollapsed" // kAXRowCollapsedNotification
  case selectedCellsChanged = "AXSelectedCellsChanged" // kAXSelectedCellsChangedNotification
  case unitsChanged = "AXUnitsChanged" // kAXUnitsChangedNotification
  case selectedChildrenMoved = "AXSelectedChildrenMoved" // kAXSelectedChildrenMovedNotification
  case selectedChildrenChanged = "AXSelectedChildrenChanged" // kAXSelectedChildrenChangedNotification
  case resized = "AXResized" // kAXResizedNotification
  case moved = "AXMoved" // kAXMovedNotification
  case created = "AXCreated" // kAXCreatedNotification
  case selectedRowsChanged = "AXSelectedRowsChanged" // kAXSelectedRowsChangedNotification
  case selectedColumnsChanged = "AXSelectedColumnsChanged" // kAXSelectedColumnsChangedNotification
  case selectedTextChanged = "AXSelectedTextChanged" // kAXSelectedTextChangedNotification
  case titleChanged = "AXTitleChanged" // kAXTitleChangedNotification
  case layoutChanged = "AXLayoutChanged" // kAXLayoutChangedNotification
  case announcementRequested = "AXAnnouncementRequested" // kAXAnnouncementRequestedNotification
  /// Additional notifications that can be sent, but will not be received by AppKit.
  case scrollPositionChanged
  case applicationTerminated
}
