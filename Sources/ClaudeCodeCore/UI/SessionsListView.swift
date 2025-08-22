//
//  SessionsListView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/14/2025.
//

import SwiftUI

struct SessionsListView: View {
  @Binding var viewModel: ChatViewModel
  @Environment(\.dismiss) private var dismiss
  @Environment(\.openWindow) private var openWindow
  
  var body: some View {
    VStack {
      HStack {
        Text("Sessions")
          .font(.headline)
          
        Spacer()
        
        Button(action: {
          Task {
            await viewModel.loadSessions()
          }
        }) {
          Image(systemName: "arrow.clockwise")
            .font(.headline)
        }
        .buttonStyle(.plain)
        .disabled(viewModel.isLoadingSessions)
      }
      .padding()
      
      if viewModel.isLoadingSessions {
        VStack {
          Spacer()
          ProgressView()
            .progressViewStyle(CircularProgressViewStyle())
            .scaleEffect(0.8)
          Text("Loading sessions...")
            .font(.callout)
            .foregroundColor(.secondary)
            .padding()
          Spacer()
        }
      } else if let error = viewModel.sessionsError {
        VStack {
          Spacer()
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.largeTitle)
            .foregroundColor(.orange)
            .padding()
          Text("Failed to load sessions")
            .font(.headline)
          Text(error.localizedDescription)
            .font(.caption)
            .foregroundColor(.secondary)
            .multilineTextAlignment(.center)
            .padding()
          Button("Retry") {
            Task {
              await viewModel.loadSessions()
            }
          }
          .buttonStyle(.bordered)
          .padding()
          Spacer()
        }
      } else {
        List {
        if viewModel.sessions.isEmpty {
          Text("No previous sessions")
            .foregroundColor(.gray)
            .italic()
            .frame(maxWidth: .infinity, alignment: .center)
            .listRowBackground(Color.clear)
        } else {
          ForEach(viewModel.sessions) { session in
            HStack {
              Button(action: {
                // Open session in new window
                openWindow(id: "session", value: session.id)
                dismiss()
              }) {
                HStack {
                  VStack(alignment: .leading) {
                    Text(session.title)
                      .font(.headline)
                    
                    Text("Last accessed: \(formattedDate(session.lastAccessedAt))")
                      .font(.caption)
                      .foregroundColor(.gray)
                  }
                  
                  Spacer()
                  
                  if session.id == viewModel.currentSessionId {
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundColor(.blue)
                  }
                }
                .contentShape(Rectangle())
              }
              .buttonStyle(.plain)
              
              // Delete button
              Button(action: {
                Task {
                  await viewModel.sessionManager.deleteSession(id: session.id)
                }
              }) {
                Image(systemName: "trash")
                  .foregroundColor(.red)
              }
              .buttonStyle(.plain)
              .help("Delete session")
            }
          }
        }
        }
      }
      
      HStack {
        Button("New Session") {
          // Open a new window with a fresh session
          openWindow(id: "main")
          dismiss()
        }
        .buttonStyle(.bordered)
        
        Spacer()
        
        Button("Close") {
          dismiss()
        }
        .buttonStyle(.bordered)
      }
      .padding()
    }
  }
  
  private func formattedDate(_ date: Date) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .medium
    formatter.timeStyle = .short
    return formatter.string(from: date)
  }
}
