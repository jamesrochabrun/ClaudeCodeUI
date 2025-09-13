import Foundation
import SwiftUI

// MARK: - SessionPickerView

/// Session picker component for selecting or creating sessions
struct SessionPickerView: View {
  let chatViewModel: ChatViewModel
  let isLoadingSessions: Bool
  let sessionLoadError: Error?
  let availableSessions: [StoredSession]
  let currentSessionId: String?
  let appsRepoRootPath: String?
  let onCancel: () -> Void
  let onTryAgain: () -> Void
  let onStartNewSession: () -> Void
  let onRestoreSession: (StoredSession) -> Void
  let onDeleteSession: (StoredSession) -> Void

  var body: some View {
    VStack(spacing: 0) {
      SessionPickerHeader(onCancel: onCancel)
      Divider()
      SessionPickerContent(
        isLoadingSessions: isLoadingSessions,
        sessionLoadError: sessionLoadError,
        availableSessions: availableSessions,
        currentSessionId: currentSessionId,
        appsRepoRootPath: appsRepoRootPath,
        onTryAgain: onTryAgain,
        onStartNewSession: onStartNewSession,
        onRestoreSession: onRestoreSession,
        onDeleteSession: onDeleteSession,
      )
    }
    .background(Color(NSColor.windowBackgroundColor))
  }
}

// MARK: - SessionPickerHeader

/// Header component for the session picker
struct SessionPickerHeader: View {
  let onCancel: () -> Void

  var body: some View {
    HStack {
      Text("Select Session")
        .font(.title2)
        .fontWeight(.semibold)

      Spacer()

      Button("Cancel") {
        onCancel()
      }
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
  }
}
