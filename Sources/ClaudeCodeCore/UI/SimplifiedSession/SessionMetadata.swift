//
//  SessionMetadata.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/13/25.
//

import Foundation
import SwiftUI

// MARK: - SessionMetadata

struct SessionMetadata: View {
  let messageCount: Int
  let lastAccessedAt: Date
  let workingDirectory: String?

  var body: some View {
    HStack(spacing: 8) {
      Text("\(messageCount) messages")
        .font(.caption)
        .foregroundColor(.secondary)

      if let dir = workingDirectory, !dir.isEmpty {
        Text("•")
          .font(.caption)
          .foregroundColor(.secondary)

        HStack(spacing: 2) {
          Image(systemName: "folder")
            .font(.caption2)
          Text(dir.split(separator: "/").last.map(String.init) ?? "folder")
            .font(.caption)
        }
        .foregroundColor(.secondary)
      }
    }
  }
}
