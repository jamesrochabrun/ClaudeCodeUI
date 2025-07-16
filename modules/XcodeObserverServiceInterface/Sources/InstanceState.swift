import AppKit
import Foundation

// MARK: - InstanceState

/// The state of one Xcode instance.
public struct InstanceState: Equatable, Sendable {

  // MARK: Lifecycle

  public init(
    isActive: Bool,
    processId: Int32,
    focusedWindow: AXUIElement?,
    focusedElement: AXUIElement?,
    windows: [WindowState]
  ) {
    self.isActive = isActive
    self.processId = processId
    self.focusedWindow = focusedWindow
    self.focusedElement = focusedElement
    self.windows = windows
  }

  // MARK: Public

  /// Whether the instance is active.
  public let isActive: Bool
  /// The process identifier of this instance.
  public let processId: Int32
  /// Which window is currently focussed.
  public let focusedWindow: AXUIElement?
  /// Which element is currently focussed.
  public let focusedElement: AXUIElement?
  /// A list of all windows that belong to the instance, ordered from when they were most recently were active.
  public let windows: [WindowState]

}

extension InstanceState {
  /// Which workspace window is currently focussed.
  public var focusedWorkspaceState: WorkspaceState? {
    focusedWindowState?.workspace
  }

  /// The state of the currently focussed window, if one has focus.
  public var focusedWindowState: WindowState? {
    if isActive {
      return windows.first
    }
    return nil
  }
}

extension [InstanceState] {
  public var activeInstance: InstanceState? {
    first(where: \.isActive)
  }
}
