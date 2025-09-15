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
  let globalPreferences: GlobalPreferencesStorage?
  let onTap: (String?) -> Void

  var body: some View {
    Button(action: {
      // Use default directory if set, otherwise nil
      let defaultDir = globalPreferences?.defaultWorkingDirectory
      onTap(defaultDir?.isEmpty == false ? defaultDir : nil)
    }) {
      HStack {
        Image(systemName: "plus.circle.fill")
          .foregroundColor(.blue)
          .font(.title3)

        VStack(alignment: .leading, spacing: 4) {
          Text("New Session")
            .font(.headline)
            .foregroundColor(.primary)
          if let defaultDir = globalPreferences?.defaultWorkingDirectory, !defaultDir.isEmpty {
            Text("Using: \(defaultDir.split(separator: "/").last.map(String.init) ?? "folder")")
              .font(.caption)
              .foregroundColor(.secondary)
          } else {
            Text("Start fresh conversation")
              .font(.caption)
              .foregroundColor(.secondary)
          }
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