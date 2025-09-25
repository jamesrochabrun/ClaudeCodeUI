//
//  SessionRow.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/13/25.
//

import Foundation
import SwiftUI

// MARK: - SessionRow

struct SessionRow: View {
  let session: StoredSession
  let isCurrentSession: Bool
  let onTap: () -> Void
  let onDelete: () -> Void
  
  var body: some View {
    HStack {
      Button(action: onTap) {
        HStack {
          VStack(alignment: .leading, spacing: 4) {
            HStack {
              Text(session.firstUserMessage.truncateIntelligently(to: 100))
                .font(.headline)
                .foregroundColor(.primary)
                .lineLimit(1)
              
              if isCurrentSession {
                Image(systemName: "circle.fill")
                  .font(.caption2)
                  .foregroundColor(.green)
              }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            SessionMetadata(
              messageCount: session.messages.count,
              lastAccessedAt: session.lastAccessedAt,
              workingDirectory: session.workingDirectory
            )
          }
          Spacer()
        }
        .padding(.vertical, 8)
        .background(isCurrentSession ? Color.green.opacity(0.1) : Color.clear)
        .cornerRadius(6)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .frame(maxWidth: .infinity, alignment: .leading)
      
      Button(action: onDelete) {
        Image(systemName: "trash")
          .font(.caption)
      }
      .buttonStyle(.plain)
      .padding(.leading, 8)
    }
  }
}
