import AppKit

// MARK: - WindowState

public struct WindowState: Equatable, Sendable {
  public let element: AXUIElement
  public let workspace: WorkspaceState?

  public init(element: AXUIElement, workspace: WorkspaceState?) {
    self.element = element
    self.workspace = workspace
  }
}
