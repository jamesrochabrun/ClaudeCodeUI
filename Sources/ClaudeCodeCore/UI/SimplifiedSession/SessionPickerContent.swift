//
//  SessionPickerContent.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/13/25.
//

import Foundation
import SwiftUI

// MARK: - SessionPickerContent

/// Content component that handles different states of the session picker
struct SessionPickerContent: View {
  let isLoadingSessions: Bool
  let sessionLoadError: Error?
  let availableSessions: [StoredSession]
  let currentSessionId: String?
  let globalPreferences: GlobalPreferencesStorage?
  let onTryAgain: () -> Void
  let onStartNewSession: (String?) -> Void
  let onRestoreSession: (StoredSession) -> Void
  let onDeleteSession: (StoredSession) -> Void
  
  var body: some View {
    if isLoadingSessions {
      LoadingSessionsView()
    } else if let error = sessionLoadError {
      SessionErrorView(
        error: error,
        onTryAgain: onTryAgain,
      )
    } else {
      SessionsListView(
        availableSessions: availableSessions,
        currentSessionId: currentSessionId,
        globalPreferences: globalPreferences,
        onStartNewSession: onStartNewSession,
        onRestoreSession: onRestoreSession,
        onDeleteSession: onDeleteSession,
      )
    }
  }
}

// MARK: - LoadingSessionsView

/// Loading state view for when sessions are being fetched
private struct LoadingSessionsView: View {
  var body: some View {
    VStack {
      ProgressView("Loading sessions...")
      Text("Fetching your conversation history")
        .foregroundColor(.secondary)
        .font(.caption)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

// MARK: - SessionErrorView

/// Error state view for when session loading fails
private struct SessionErrorView: View {
  let error: Error
  let onTryAgain: () -> Void
  
  var body: some View {
    VStack {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundColor(.orange)
      
      Text("Error loading sessions")
        .font(.headline)
      
      Text(error.localizedDescription)
        .font(.caption)
        .foregroundColor(.secondary)
      
      Button("Try Again") {
        onTryAgain()
      }
      .buttonStyle(.bordered)
    }
    .padding()
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}
