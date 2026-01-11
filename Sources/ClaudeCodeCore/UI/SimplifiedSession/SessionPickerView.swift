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
  let globalPreferences: GlobalPreferencesStorage?
  let cliSessionsViewModel: CLISessionsViewModel?
  let onCancel: () -> Void
  let onTryAgain: () -> Void
  let onStartNewSession: (String?) -> Void
  let onRestoreSession: (StoredSession) -> Void
  let onDeleteSession: (StoredSession) -> Void
  let onDeleteAll: () -> Void

  var body: some View {
    VStack(spacing: 0) {
      SessionPickerHeader(
        onCancel: onCancel,
        onDeleteAll: onDeleteAll,
        sessionCount: availableSessions.count
      )
      Divider()
      SessionPickerContent(
        isLoadingSessions: isLoadingSessions,
        sessionLoadError: sessionLoadError,
        availableSessions: availableSessions,
        currentSessionId: currentSessionId,
        globalPreferences: globalPreferences,
        cliSessionsViewModel: cliSessionsViewModel,
        onTryAgain: onTryAgain,
        onStartNewSession: onStartNewSession,
        onRestoreSession: onRestoreSession,
        onDeleteSession: onDeleteSession
      )
    }
    .background(Color(NSColor.windowBackgroundColor))
  }
}

// MARK: - SessionPickerHeader

/// Header component for the session picker
struct SessionPickerHeader: View {
  let onCancel: () -> Void
  let onDeleteAll: () -> Void
  let sessionCount: Int

  var body: some View {
    HStack {
      Text("Select Session")
        .font(.title2)
        .fontWeight(.semibold)

      Spacer()

      if sessionCount > 0 {
        Button("Delete All") {
          onDeleteAll()
        }
        .foregroundColor(.red)
      }

      Button("Cancel") {
        onCancel()
      }
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
  }
}
