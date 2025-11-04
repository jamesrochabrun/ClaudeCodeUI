//
//  RequirementRow.swift
//  ClaudeCodeUI
//
//  Created by Claude on 2025-11-03.
//

import SwiftUI
import AppKit

/// UI component showing a single requirement with status and install command
struct RequirementRow: View {
  let title: String
  let isInstalled: Bool
  let installCommand: String

  var body: some View {
    HStack(spacing: 12) {
      Image(systemName: isInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
        .foregroundColor(isInstalled ? .green : .red)
        .imageScale(.large)

      VStack(alignment: .leading, spacing: 4) {
        Text(title)
          .font(.body)

        if !isInstalled {
          Text(installCommand)
            .font(.caption)
            .foregroundColor(.secondary)
            .textSelection(.enabled)
        }
      }

      Spacer()

      if !isInstalled {
        Button("Copy") {
          NSPasteboard.general.clearContents()
          NSPasteboard.general.setString(installCommand, forType: .string)
        }
        .buttonStyle(.borderless)
      }
    }
    .padding(.vertical, 4)
  }
}
