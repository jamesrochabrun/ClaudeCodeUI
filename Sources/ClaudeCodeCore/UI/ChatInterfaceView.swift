import ClaudeCodeSDK
import Foundation
import SwiftUI

// MARK: - ChatInterfaceView

struct ChatInterfaceView: View {
  let chatViewModel: ChatViewModel
  let globalPreferences: GlobalPreferencesStorage
  let claudeCodeDeps: DependencyContainer
  let availableSessions: [StoredSession]
  let uiConfig: UIConfiguration
  let onShowSessionPicker: () -> Void
  
  var body: some View {
    ChatScreen(
      viewModel: chatViewModel,
      contextManager: claudeCodeDeps.contextManager,
      xcodeObservationViewModel: claudeCodeDeps.xcodeObservationViewModel,
      permissionsService: claudeCodeDeps.permissionsService,
      terminalService: claudeCodeDeps.terminalService,
      customPermissionService: claudeCodeDeps.customPermissionService,
      columnVisibility: .constant(.detailOnly),
      uiConfiguration: uiConfig,
    )
    .environment(globalPreferences)
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .toolbar {
      ToolbarItem(placement: .primaryAction) {
        Button("Sessions") {
          onShowSessionPicker()
        }
      }
    }
  }
}
