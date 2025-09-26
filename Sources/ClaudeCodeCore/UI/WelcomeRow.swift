//
//  WelcomeRow.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 6/21/25.
//

import Foundation
import SwiftUI
import AppKit

struct WelcomeRow: View {
  let path: String?
  let showSettingsButton: Bool
  let appName: String
  let toolTip: String?
  let onSettingsTapped: () -> Void
  let onWorktreeSelected: ((String) -> Void)?

  @State private var availableWorktrees: [GitWorktreeInfo] = []
  @State private var isExpanded = false
  @State private var isLoadingWorktrees = false

  // Custom color
  init(
    path: String?,
    showSettingsButton: Bool = false,
    appName: String = "Claude Code UI",
    toolTip: String? = nil,
    onSettingsTapped: @escaping () -> Void = {},
    onWorktreeSelected: ((String) -> Void)? = nil
  ) {
    self.path = path
    self.showSettingsButton = showSettingsButton
    self.appName = appName
    self.toolTip = toolTip
    self.onSettingsTapped = onSettingsTapped
    self.onWorktreeSelected = onWorktreeSelected
  }
  
  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text("✻")
        .foregroundColor(.brandPrimary)
      VStack(alignment: .leading, spacing: 16) {
        Text("Welcome to **\(appName)!**")
          .font(.system(.body, design: .monospaced))
          .foregroundColor(.primary)
        
        if showSettingsButton {
          VStack(alignment: .leading, spacing: 8) {
            Text("No working directory selected")
              .font(.system(.caption, design: .monospaced))
              .foregroundColor(.orange)
            
            if let toolTip = toolTip {
              Text(toolTip)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)
            }
            
            Button(action: onSettingsTapped) {
              HStack(spacing: 4) {
                Image(systemName: "folder.badge.plus")
                  .font(.system(size: 14))
                Text("Select Working Directory")
                  .font(.system(.body, design: .monospaced))
              }
              .foregroundColor(.brandPrimary)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(Color.brandPrimary.opacity(0.1))
              .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Select a working directory for this session")
          }
        } else if let path = path {
          VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
              Text(path)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.secondary)

              Button(action: onSettingsTapped) {
                Image(systemName: "pencil.circle")
                  .font(.caption)
              }
              .buttonStyle(.plain)
              .foregroundColor(.secondary)
              .help("Change working directory")

              // Show worktrees button if available
              if availableWorktrees.count > 1 {
                Spacer()
                Button(action: { isExpanded.toggle() }) {
                  HStack(spacing: 4) {
                    Image(systemName: "arrow.triangle.branch")
                      .font(.caption)
                    Text("\(availableWorktrees.count) worktrees")
                      .font(.system(.caption, design: .monospaced))
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                      .font(.caption2)
                  }
                  .foregroundColor(.blue)
                  .padding(.horizontal, 8)
                  .padding(.vertical, 4)
                  .background(Color.blue.opacity(0.1))
                  .cornerRadius(4)
                }
                .buttonStyle(.plain)
              }
            }

            // Expanded worktree list
            if isExpanded && availableWorktrees.count > 1 {
              VStack(alignment: .leading, spacing: 4) {
                ForEach(availableWorktrees, id: \.path) { worktree in
                  Button(action: {
                    onWorktreeSelected?(worktree.path)
                    isExpanded = false
                  }) {
                    HStack(spacing: 8) {
                      Image(systemName: worktree.isWorktree ? "arrow.triangle.branch" : "arrow.branch")
                        .font(.caption)
                        .foregroundColor(worktree.isWorktree ? .orange : .blue)

                      VStack(alignment: .leading, spacing: 2) {
                        Text(worktree.branch ?? "unknown")
                          .font(.system(.caption, design: .monospaced))
                          .foregroundColor(.primary)
                        Text(URL(fileURLWithPath: worktree.path).lastPathComponent)
                          .font(.system(.caption2, design: .monospaced))
                          .foregroundColor(.secondary)
                      }

                      Spacer()

                      if worktree.path == path {
                        Image(systemName: "checkmark.circle.fill")
                          .font(.caption)
                          .foregroundColor(.green)
                      }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(worktree.path == path ? Color.green.opacity(0.1) : Color.clear)
                    .cornerRadius(4)
                  }
                  .buttonStyle(.plain)
                }
              }
              .padding(.top, 4)
              .padding(.horizontal, 8)
              .background(Color.gray.opacity(0.05))
              .cornerRadius(4)
              .frame(maxHeight: 150)
            }
          }
        }
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .overlay(
      RoundedRectangle(cornerRadius: 4)
        .stroke(Color.brandPrimary, lineWidth: 1)
    )
    .padding(12)
    .onAppear {
      detectWorktrees()
    }
    .onChange(of: path) { _, _ in
      detectWorktrees()
    }
  }

  private func detectWorktrees() {
    guard let path = path else {
      availableWorktrees = []
      return
    }

    // Clean the path - remove "cwd: " prefix if present
    let cleanPath = path.replacingOccurrences(of: "cwd: ", with: "")

    Task {
      isLoadingWorktrees = true
      availableWorktrees = await GitWorktreeDetector.listWorktrees(at: cleanPath)
      isLoadingWorktrees = false
    }
  }
}

#Preview {
  VStack {
    WelcomeRow(path: "cwd: /Users/jamesrochabrun/Desktop/git/ClaudeCodeUI", appName: "Claude Code UI")
    WelcomeRow(path: nil, showSettingsButton: true, appName: "My App") {
      print("Settings tapped")
    }
    WelcomeRow(
      path: nil,
      showSettingsButton: true,
      appName: "My App",
      toolTip: "Tip: Select a folder to enable AI assistance"
    ) {
      print("Settings tapped")
    }
  }
}
