//
//  NewSessionRow.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/13/25.
//

import Foundation
import SwiftUI

/// Row component for creating a new session
struct NewSessionRow: View {
  let projectName: String
  let onTap: () -> Void
  
  var body: some View {
    Button(action: onTap) {
      HStack {
        Image(systemName: "plus.circle.fill")
          .foregroundColor(.blue)
          .font(.title3)
        
        VStack(alignment: .leading, spacing: 4) {
          Text("New Session")
            .font(.headline)
            .foregroundColor(.primary)
          Text("Start fresh with \(projectName)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        
        Spacer()
        
        Image(systemName: "chevron.right")
          .foregroundColor(.secondary)
          .font(.caption)
      }
      .padding(.vertical, 8)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}


