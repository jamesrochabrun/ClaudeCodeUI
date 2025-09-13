import Foundation
import SwiftUI

// MARK: - SessionsListView

struct SessionsListView: View {
  let availableSessions: [StoredSession]
  let currentSessionId: String?
  let appsRepoRootPath: String?
  let onStartNewSession: () -> Void
  let onRestoreSession: (StoredSession) -> Void
  let onDeleteSession: (StoredSession) -> Void

  var body: some View {
    List {
      NewSessionRow(
        projectName: appsRepoRootPath?.split(separator: "/").last.map(String.init) ?? "current project",
        onTap: onStartNewSession,
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

