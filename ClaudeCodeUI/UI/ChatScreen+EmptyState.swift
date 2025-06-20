//
//  ChatScreen+EmptyState.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import SwiftUI

extension ChatScreen {
  var emptyStateView: some View {
    VStack(spacing: 20) {
      Spacer()
      Image(systemName: "folder.badge.questionmark")
        .font(.system(size: 60))
        .foregroundColor(.secondary)
      Text("No Working Directory Selected")
        .font(.title2)
        .fontWeight(.semibold)
      Text("Select a working directory to start chatting with Claude")
        .font(.body)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
      Button("Open Settings") {
        showingSettings = true
      }
      .buttonStyle(.borderedProminent)
      Spacer()
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
    .padding()
  }
}
