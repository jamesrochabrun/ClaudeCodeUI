//
//  CopyButton.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 2025.
//

import SwiftUI
import AppKit

/// A reusable copy button that shows visual feedback when content is copied
public struct CopyButton: View {

  // MARK: - Properties

  /// The text to copy to clipboard
  let textToCopy: String

  /// Optional custom icon size
  let iconSize: CGFloat

  /// Optional custom color
  let color: Color

  /// Tracks whether the content was just copied
  @State private var showingCopied = false

  /// Task for managing the animation delay
  @State private var animationTask: Task<Void, Never>?

  // MARK: - Initialization

  public init(
    textToCopy: String,
    iconSize: CGFloat = 12,
    color: Color = .secondary
  ) {
    self.textToCopy = textToCopy
    self.iconSize = iconSize
    self.color = color
  }

  // MARK: - Body

  public var body: some View {
    Button(action: {
      copyToClipboard()
    }) {
      Image(systemName: showingCopied ? "checkmark" : "doc.on.doc")
        .font(.system(size: iconSize))
        .foregroundColor(showingCopied ? .green : color)
        .animation(.easeInOut(duration: 0.2), value: showingCopied)
    }
    .buttonStyle(.plain)
    .help(showingCopied ? "Copied!" : "Copy to clipboard")
    .disabled(showingCopied)
    .onDisappear {
      // Cancel any pending animation task when view disappears
      animationTask?.cancel()
    }
  }

  // MARK: - Private Methods

  private func copyToClipboard() {
    // Copy text to clipboard
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(textToCopy, forType: .string)

    // Cancel any existing animation task
    animationTask?.cancel()

    // Show feedback
    withAnimation {
      showingCopied = true
    }

    // Reset after 1 second using modern concurrency
    animationTask = Task {
      do {
        try await Task.sleep(for: .seconds(1))

        // Check if task wasn't cancelled
        if !Task.isCancelled {
          withAnimation {
            showingCopied = false
          }
        }
      } catch {
        // Task was cancelled, which is fine
      }
    }
  }
}

// MARK: - Preview

#Preview("Copy Button States") {
  VStack(spacing: 20) {
    // Default state
    VStack {
      Text("Default State")
        .font(.caption)
      CopyButton(textToCopy: "Hello, World!")
    }

    // Custom size and color
    VStack {
      Text("Custom Size & Color")
        .font(.caption)
      CopyButton(
        textToCopy: "Custom styled text",
        iconSize: 16,
        color: .blue
      )
    }

    // In a toolbar-like context
    HStack {
      Text("In toolbar:")
      Spacer()
      CopyButton(textToCopy: "Toolbar text")
    }
    .padding()
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(8)
  }
  .padding()
  .frame(width: 300)
}

#Preview("Copy Button Animation") {
  // This preview shows the button in action
  CopyButton(textToCopy: "Click me to see the animation!")
    .scaleEffect(2) // Make it bigger for preview
    .padding()
}