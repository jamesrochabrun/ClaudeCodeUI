//
//  WelcomeRow.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 6/21/25.
//

import Foundation
import SwiftUI
import AppKit

// MARK: - Subcomponents

private struct WelcomeHeader: View {
  let appName: String

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text("✻")
        .foregroundColor(.brandPrimary)

      Text("Welcome to **\(appName)!**")
        .font(.system(.body, design: .monospaced))
        .foregroundColor(.primary)
    }
  }
}

private struct NoDirectoryView: View {
  let toolTip: String?
  let onSettingsTapped: () -> Void

  var body: some View {
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
  }
}

private struct WorkingDirectoryHeader: View {
  let path: String
  let worktreeCount: Int
  let isExpanded: Bool
  let onEditTapped: () -> Void
  let onToggleExpanded: () -> Void

  var body: some View {
    HStack(spacing: 8) {
      Text(path)
        .font(.system(.caption, design: .monospaced))
        .foregroundColor(.secondary)

      Button(action: onEditTapped) {
        Image(systemName: "pencil.circle")
          .font(.caption)
      }
      .buttonStyle(.plain)
      .foregroundColor(.secondary)
      .help("Change working directory")

      if worktreeCount > 1 {
        Spacer()
        Button(action: onToggleExpanded) {
          HStack(spacing: 4) {
            Image(systemName: "arrow.triangle.branch")
              .font(.caption)
            Text("\(worktreeCount) worktrees")
              .font(.system(.caption, design: .monospaced))
            Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
              .font(.caption2)
          }
          .foregroundColor(.brandPrimary)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.brandPrimary.opacity(0.1))
          .cornerRadius(4)
        }
        .buttonStyle(.plain)
      }
    }
  }
}

private struct WorktreeListItem: View {
  let worktree: GitWorktreeInfo
  let isSelected: Bool
  let onSelect: () -> Void

  var body: some View {
    Button(action: onSelect) {
      HStack(spacing: 8) {
        Image(systemName: worktree.isWorktree ? "arrow.triangle.branch" : "arrow.branch")
          .font(.caption)
          .foregroundColor(isSelected ? .white : .secondary)

        VStack(alignment: .leading, spacing: 2) {
          Text(worktree.branch ?? "unknown")
            .font(.system(.caption, design: .monospaced))
            .foregroundColor(isSelected ? .white : .primary)
          Text(URL(fileURLWithPath: worktree.path).lastPathComponent)
            .font(.system(.caption2, design: .monospaced))
            .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
        }

        Spacer()

        if isSelected {
          Image(systemName: "checkmark.circle.fill")
            .font(.caption)
            .foregroundColor(.white)
        }
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .frame(maxWidth: .infinity, alignment: .leading)
      .background(isSelected ? Color.brandPrimary.opacity(0.8) : Color.clear)
      .clipShape(RoundedRectangle(cornerRadius: 4, style: .circular))
      .contentShape(RoundedRectangle(cornerRadius: 4, style: .circular))
    }
    .buttonStyle(.plain)
  }
}

private struct WorktreeListView: View {
  let worktrees: [GitWorktreeInfo]
  let currentPath: String
  let onWorktreeSelected: (String) -> Void

  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      ForEach(worktrees, id: \.path) { worktree in
        WorktreeListItem(
          worktree: worktree,
          isSelected: {
            let currentClean = currentPath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
            let worktreeClean = worktree.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))

            // Exact match
            if currentClean == worktreeClean {
              return true
            }

            // Check if current is subdirectory (with separator to avoid prefix collision)
            return currentClean.hasPrefix(worktreeClean + "/")
          }(),
          onSelect: {
            onWorktreeSelected(worktree.path)
          }
        )
      }
    }
    .padding(.vertical, 8)
    .padding(.horizontal, 8)
    .background(Color.brandSecondary.opacity(0.2))
    .clipShape(RoundedRectangle(cornerRadius: 4, style: .circular))
  }
}

// MARK: - Main Component

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
  @State private var showInvalidPathAlert = false
  @State private var invalidPathMessage = ""
  
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
    VStack(alignment: .leading, spacing: 16) {
      WelcomeHeader(appName: appName)

      if showSettingsButton {
        NoDirectoryView(
          toolTip: toolTip,
          onSettingsTapped: onSettingsTapped
        )
      } else if let path = path {
        VStack(alignment: .leading, spacing: 8) {
          WorkingDirectoryHeader(
            path: path,
            worktreeCount: availableWorktrees.count,
            isExpanded: isExpanded,
            onEditTapped: onSettingsTapped,
            onToggleExpanded: {
              isExpanded.toggle()
            }
          )

          if isExpanded && availableWorktrees.count > 1 {
            WorktreeListView(
              worktrees: availableWorktrees,
              currentPath: path.replacingOccurrences(of: "cwd: ", with: ""),
              onWorktreeSelected: { selectedPath in
                // Validate worktree path exists before switching
                if FileManager.default.fileExists(atPath: selectedPath) {
                  onWorktreeSelected?(selectedPath)
                  isExpanded = false
                } else {
                  // Show alert for invalid path
                  invalidPathMessage = "The worktree at '\(URL(fileURLWithPath: selectedPath).lastPathComponent)' no longer exists. It may have been removed or moved."
                  showInvalidPathAlert = true
                  // Refresh worktree list to remove stale entries
                  detectWorktrees()
                }
              }
            )
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
    .alert("Worktree Not Found", isPresented: $showInvalidPathAlert) {
      Button("OK", role: .cancel) { }
    } message: {
      Text(invalidPathMessage)
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
  // Create a custom WelcomeRow with mock worktrees for preview
  struct PreviewWrapper: View {
    @State private var currentPath = "cwd: /Users/jamesrochabrun/Desktop/git/ClaudeCodeUI-feature-branch"

    var body: some View {
      VStack(spacing: 20) {
        // Preview with no directory selected
        WelcomeRow(
          path: nil,
          showSettingsButton: true,
          appName: "Claude Code UI",
          toolTip: "Tip: Select a folder to enable AI assistance"
        ) {
          print("Settings tapped")
        }

        // Preview with directory but no worktrees
        WelcomeRow(
          path: "cwd: /Users/jamesrochabrun/Desktop/simple-project",
          appName: "Claude Code UI"
        ) {
          print("Edit directory tapped")
        }

        // Create a modified WelcomeRow with mock worktrees
        MockWorktreeWelcomeRow(
          currentPath: $currentPath
        )

        Spacer()
      }
      .frame(width: 600)
      .padding()
    }
  }

  // Mock version of WelcomeRow with hardcoded worktrees for preview
  struct MockWorktreeWelcomeRow: View {
    @Binding var currentPath: String
    @State private var isExpanded = true  // Start expanded to see worktrees in preview

    // Mock worktrees for preview
    let mockWorktrees = [
      GitWorktreeInfo(
        path: "/Users/jamesrochabrun/Desktop/git/ClaudeCodeUI",
        branch: "main",
        isWorktree: false,
        mainRepoPath: nil
      ),
      GitWorktreeInfo(
        path: "/Users/jamesrochabrun/Desktop/git/ClaudeCodeUI-feature-branch",
        branch: "feature/new-ui",
        isWorktree: true,
        mainRepoPath: "/Users/jamesrochabrun/Desktop/git/ClaudeCodeUI"
      ),
      GitWorktreeInfo(
        path: "/Users/jamesrochabrun/Desktop/git/ClaudeCodeUI-bugfix",
        branch: "bugfix/crash-on-launch",
        isWorktree: true,
        mainRepoPath: "/Users/jamesrochabrun/Desktop/git/ClaudeCodeUI"
      ),
      GitWorktreeInfo(
        path: "/Users/jamesrochabrun/Desktop/git/ClaudeCodeUI-experiment",
        branch: "experiment/ai-suggestions",
        isWorktree: true,
        mainRepoPath: "/Users/jamesrochabrun/Desktop/git/ClaudeCodeUI"
      )
    ]

    var body: some View {
      VStack(alignment: .leading, spacing: 16) {
        WelcomeHeader(appName: "Claude Code UI")

        VStack(alignment: .leading, spacing: 8) {
          WorkingDirectoryHeader(
            path: currentPath,
            worktreeCount: mockWorktrees.count,
            isExpanded: isExpanded,
            onEditTapped: { print("Edit tapped") },
            onToggleExpanded: { isExpanded.toggle() }
          )

          if isExpanded && mockWorktrees.count > 1 {
            WorktreeListView(
              worktrees: mockWorktrees,
              currentPath: currentPath.replacingOccurrences(of: "cwd: ", with: ""),
              onWorktreeSelected: { path in
                currentPath = "cwd: \(path)"
                isExpanded = false
                print("Selected worktree: \(path)")
              }
            )
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
    }
  }

  return PreviewWrapper()
}
