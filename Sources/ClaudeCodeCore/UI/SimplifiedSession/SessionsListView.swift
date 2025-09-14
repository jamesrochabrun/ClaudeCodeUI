import Foundation
import SwiftUI

// MARK: - SessionsListView

struct SessionsListView: View {
  let availableSessions: [StoredSession]
  let currentSessionId: String?
  let globalPreferences: GlobalPreferencesStorage?
  let onStartNewSession: (String?) -> Void
  let onRestoreSession: (StoredSession) -> Void
  let onDeleteSession: (StoredSession) -> Void

  @State private var showDirectoryPicker = false
  @State private var selectedDirectory: String?

  var body: some View {
    List {
      NewSessionRow(
        globalPreferences: globalPreferences,
        onTap: { directory in
          onStartNewSession(directory)
        }
      )

      if !availableSessions.isEmpty {
        Section("Previous Sessions") {
          ForEach(availableSessions) { session in
            SessionRow(
              session: session,
              isCurrentSession: session.id == currentSessionId,
              onTap: { onRestoreSession(session) },
              onDelete: { onDeleteSession(session) },
            )
          }
        }
      }
    }
  }
}

