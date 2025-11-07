//
//  CompactDiffStatusView.swift
//  ClaudeCodeUI
//
//  Created on 11/06/25.
//

import SwiftUI

/// A compact view showing that changes have been reviewed
///
/// This view is used to replace full diff displays after a user has processed them,
/// significantly improving performance in long sessions. Users can tap to expand
/// and see the full diff in a modal if needed.
struct CompactDiffStatusView: View {

  // MARK: - Properties

  let fileName: String
  let timestamp: Date?
  let onTapToExpand: () -> Void

  private var icon: String {
    "checkmark.circle.fill"
  }

  private var label: String {
    "Changes Reviewed"
  }

  // MARK: - Body

  var body: some View {
    HStack(spacing: 8) {
      // Status icon
      Image(systemName: icon)
        .foregroundColor(.brandPrimary)
        .font(.system(size: 12))

      // File info
      VStack(alignment: .leading, spacing: 2) {
        Text(label)
          .font(.caption)
          .foregroundColor(.brandPrimary)

        Text(fileName)
          .font(.caption2)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }

      Spacer()
    }
    .padding(8)
    .background(
      RoundedRectangle(cornerRadius: 6)
        .fill(Color.secondary.opacity(0.05))
    )
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .stroke(Color.brandPrimary.opacity(0.2), lineWidth: 0.5)
    )
    .contentShape(Rectangle())
    .onTapGesture(perform: onTapToExpand)
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 16) {
    CompactDiffStatusView(
      fileName: "src/auth/login.ts",
      timestamp: Date().addingTimeInterval(-300),
      onTapToExpand: {}
    )

    CompactDiffStatusView(
      fileName: "src/components/UserProfile.tsx",
      timestamp: Date().addingTimeInterval(-60),
      onTapToExpand: {}
    )

    CompactDiffStatusView(
      fileName: "very/long/path/to/some/deeply/nested/file/Component.swift",
      timestamp: nil,
      onTapToExpand: {}
    )
  }
  .padding()
}
