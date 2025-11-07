//
//  TipBannerView.swift
//  ClaudeCodeUI
//
//  Created on 11/7/24.
//

import SwiftUI

/// A dismissable banner view for displaying tips to users
struct TipBannerView: View {

  // MARK: - Properties

  let message: String
  let icon: String
  let onDismiss: () -> Void

  @State private var isHovering = false

  // MARK: - Body

  var body: some View {
    HStack(spacing: 10) {
      // Icon
      Image(systemName: icon)
        .foregroundColor(.brandSecondary)
        .font(.system(size: 14))

      // Message
      Text(message)
        .font(.caption2)
        .foregroundColor(.primary.opacity(0.9))

      // Dismiss button - matching ActiveFileView pattern
      Button(action: onDismiss) {
        Image(systemName: "xmark.circle.fill")
          .foregroundColor(.secondary.opacity(isHovering ? 0.8 : 0.6))
          .font(.system(size: 14))
      }
      .buttonStyle(.plain)
      .help("Dismiss tip")
      .onHover { hovering in
        isHovering = hovering
      }
    }
    .padding(.horizontal, 8)
  }
}

// MARK: - Preview

#Preview {
  VStack(spacing: 20) {
    TipBannerView(
      message: "Press Cmd+I to capture code selection or send active file to context",
      icon: "command.circle",
      onDismiss: {}
    )
    .padding()

    TipBannerView(
      message: "Set a working directory to enable full AI code assistance",
      icon: "folder.badge.gearshape",
      onDismiss: {}
    )
    .padding()
  }
}
