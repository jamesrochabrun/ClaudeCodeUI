//
//  SessionsSidebarView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/14/2025.
//

import SwiftUI
import ClaudeCodeSDK
import CustomPermissionService

struct SessionsSidebarView: View {
  @State var viewModel: ChatViewModel
  @Environment(\.openWindow) private var openWindow
  @State private var showingDeleteAllConfirmation = false
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text("Sessions")
          .font(.headline)
          .foregroundColor(.primary)
        
        Spacer()
        
        Button(action: {
          Task {
            await viewModel.loadSessions()
          }
        }) {
          Image(systemName: "arrow.clockwise")
            .font(.system(size: 12))
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoadingSessions)
        .help("Refresh sessions")
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
      
      Divider()
      
      // Sessions List
      if viewModel.isLoadingSessions {
        loadingView
      } else if let error = viewModel.sessionsError {
        errorView(error)
      } else {
        sessionsList
      }
      
      Divider()
      
      // Footer with New Session and Delete All buttons
      HStack {
        Button(action: {
          // Start a new session without clearing the current one
          // Just clear the message store and session manager state for a fresh start
          viewModel.startNewSession()
        }) {
          Label("New Session", systemImage: "plus.circle")
            .font(.system(size: 13))
        }
        .buttonStyle(.plain)
        
        Spacer()
        
        Button(action: {
          showingDeleteAllConfirmation = true
        }) {
          Image(systemName: "trash")
            .font(.system(size: 12))
            .foregroundColor(.red)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.sessions.isEmpty)
        .help("Delete all sessions")
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .background(.ultraThinMaterial)
    .onAppear {
      // Load sessions when sidebar appears
      Task {
        await viewModel.loadSessions()
      }
    }
    .confirmationDialog(
      "Delete All Sessions",
      isPresented: $showingDeleteAllConfirmation,
      titleVisibility: .visible
    ) {
      Button("Delete All", role: .destructive) {
        Task {
          await deleteAllSessions()
        }
      }
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("Are you sure you want to delete all sessions? This action cannot be undone.")
    }
  }
  
  private var loadingView: some View {
    VStack {
      Spacer()
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle())
        .scaleEffect(0.8)
      Text("Loading sessions...")
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.top, 8)
      Spacer()
    }
  }
  
  private func errorView(_ error: Error) -> some View {
    VStack(spacing: 8) {
      Spacer()
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.largeTitle)
        .foregroundColor(.orange)
      Text("Failed to load sessions")
        .font(.caption)
        .fontWeight(.medium)
      Text(error.localizedDescription)
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      Button("Retry") {
        Task {
          await viewModel.loadSessions()
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      Spacer()
    }
    .padding()
  }
  
  private var sessionsList: some View {
    ScrollView {
      if viewModel.sessions.isEmpty {
        VStack {
          Spacer()
          Text("No sessions yet")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("Send a message to start")
            .font(.caption2)
            .foregroundColor(Color.secondary.opacity(0.7))
          Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding()
      } else {
        LazyVStack(spacing: 0) {
          ForEach(viewModel.sessions) { session in
            SessionRowView(
              session: session,
              isActive: session.id == viewModel.currentSessionId,
              onSelect: {
                // Prevent rapid switching
                guard !viewModel.isLoading else { return }
                
                // Switch to this session
                Task {
                  await viewModel.switchToSession(session.id)
                }
              },
              onDelete: {
                Task {
                  await viewModel.deleteSession(id: session.id)
                }
              }
            )
          }
        }
        .padding(.vertical, 8)
      }
    }
  }
  
  private func deleteAllSessions() async {
    // Delete all sessions
    for session in viewModel.sessions {
      await viewModel.deleteSession(id: session.id)
    }
    
    // Clear current conversation if any
    viewModel.clearConversation()
  }
}

struct SessionRowView: View {
  let session: StoredSession
  let isActive: Bool
  let onSelect: () -> Void
  let onDelete: () -> Void
  
  @State private var isHovered = false
  @State private var lastTapTime = Date.distantPast
  
  var body: some View {
    HStack(spacing: 8) {
      // Active indicator
      if isActive {
        Image(systemName: "checkmark.circle.fill")
          .font(.system(size: 12))
          .foregroundColor(.accentColor)
          .frame(width: 12, height: 12)
      } else {
        // Placeholder for alignment
        Color.clear
          .frame(width: 12, height: 12)
      }
      
      // Session info
      VStack(alignment: .leading, spacing: 2) {
        Text(session.title)
          .font(.system(size: 13))
          .lineLimit(1)
          .foregroundColor(isActive ? .primary : .secondary)
        
        Text(relativeDate(session.lastAccessedAt))
          .font(.system(size: 11))
          .foregroundColor(Color.secondary.opacity(0.7))
      }
      
      Spacer()
      
      // Delete button (show on hover)
      if isHovered {
        Button(action: onDelete) {
          Image(systemName: "trash")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help("Delete session")
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 6)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(isActive ? Color.accentColor.opacity(0.15) : (isHovered ? Color.gray.opacity(0.08) : Color.clear))
    )
    .contentShape(Rectangle())
    .onTapGesture {
      if !isActive {
        // Debounce rapid taps (minimum 0.5 seconds between switches)
        let now = Date()
        guard now.timeIntervalSince(lastTapTime) > 0.5 else { return }
        lastTapTime = now
        onSelect()
      }
    }
    .onHover { hovering in
      isHovered = hovering
    }
    .padding(.horizontal, 8)
  }
  
  private func relativeDate(_ date: Date) -> String {
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: Date())
  }
}

#Preview {
  SessionsSidebarView(viewModel: ChatViewModel(
    claudeClient: ClaudeCodeClient(configuration: .default),
    sessionStorage: UserDefaultsSessionStorage(),
    settingsStorage: SettingsStorageManager(),
    globalPreferences: GlobalPreferencesStorage(),
    customPermissionService: DefaultCustomPermissionService()
  ))
  .frame(width: 250)
}