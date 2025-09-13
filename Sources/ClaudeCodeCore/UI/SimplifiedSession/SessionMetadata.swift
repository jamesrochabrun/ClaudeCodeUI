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

  var body: some View {
    Text("\(messageCount) messages")
      .font(.caption)
      .foregroundColor(.secondary)
  }
}
