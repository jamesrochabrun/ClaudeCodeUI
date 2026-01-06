//
//  DiffModalView.swift
//  ClaudeCodeUI
//
//  Created on 1/10/25.
//

import SwiftUI
import CCTerminalServiceInterface

/// Full-screen modal view for displaying diffs with integrated approval controls
public struct DiffModalView: View {
  // MARK: - Properties
  
  let messageID: UUID
  let editTool: EditTool
  let toolParameters: [String: String]
  let terminalService: TerminalService
  let projectPath: String?
  let diffStore: DiffStateManager? // Shared from parent, never creates its own
  let diffLifecycleState: DiffLifecycleState?

  let onDismiss: () -> Void
  
  @Environment(\.colorScheme) private var colorScheme
  
  // MARK: - Initialization
  
  public init(
    messageID: UUID,
    editTool: EditTool,
    toolParameters: [String: String],
    terminalService: TerminalService,
    projectPath: String? = nil,
    diffStore: DiffStateManager? = nil,
    diffLifecycleState: DiffLifecycleState? = nil,
    onDismiss: @escaping () -> Void
  ) {
    self.messageID = messageID
    self.editTool = editTool
    self.toolParameters = toolParameters
    self.terminalService = terminalService
    self.projectPath = projectPath
    self.diffStore = diffStore
    self.diffLifecycleState = diffLifecycleState
    self.onDismiss = onDismiss
  }
  
  // MARK: - Body
  
  public var body: some View {
    VStack(spacing: 0) {
      // Header bar
      HStack {
        Spacer()
        // Close button
        Button("Close") {
          onDismiss()
        }
        .buttonStyle(.bordered)
        .keyboardShortcut(.escape, modifiers: [])
      }
      .padding()
      .background(Color(NSColor.controlBackgroundColor))
      Divider()
      
      // Diff content
      ClaudeCodeEditsView(
        messageID: messageID,
        editTool: editTool,
        toolParameters: toolParameters,
        terminalService: terminalService,
        projectPath: projectPath,
        diffStore: diffStore,
        diffLifecycleState: diffLifecycleState
      )
      .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    .frame(minWidth: 800, minHeight: 600)
  }
  
}
