import Foundation

public struct WorkspaceState: Equatable, Sendable {

  // MARK: Lifecycle

  public init(documentURL: URL?, workspaceURL: URL?, editors: [EditorState]) {
    self.documentURL = documentURL
    self.workspaceURL = workspaceURL
    self.editors = editors
  }

  // MARK: Public

  public let documentURL: URL?
  public let workspaceURL: URL?
  public let editors: [EditorState]

  public func updatedWith(
    documentURL: URL?? = nil,
    workspaceURL: URL?? = nil,
    projectRootURL _: URL? = nil,
    editors: [EditorState]? = nil
  ) -> WorkspaceState {
    .init(
      documentURL: documentURL ?? self.documentURL,
      workspaceURL: workspaceURL ?? self.workspaceURL,
      editors: editors ?? self.editors
    )
  }
}
