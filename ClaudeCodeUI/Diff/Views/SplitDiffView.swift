//
//  SplitDiffView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import SwiftUI

/// Side-by-side diff view showing original and modified code in separate columns
struct SplitDiffView: View {
  let formattedDiff: FormattedFileChange
  
  @Environment(\.colorScheme) private var colorScheme
  
  private enum Constants {
    static let fontSize: CGFloat = 11
    static let lineNumberWidth: CGFloat = 50
  }
  
  private var syncedLines: [SyncedLine] {
    processSynchronizedLines()
  }
  
  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      // Left column (original)
      column(side: .left)
      
      // Divider
      Rectangle()
        .fill(Color.gray.opacity(0.3))
        .frame(width: 1)
      
      // Right column (modified)
      column(side: .right)
    }
    .frame(maxWidth: .infinity)
  }
  
  @ViewBuilder
  private func column(side: ColumnSide) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(syncedLines) { line in
        lineView(for: line, side: side)
      }
    }
    .frame(maxWidth: .infinity)
  }
  
  @ViewBuilder
  private func lineView(for line: SyncedLine, side: ColumnSide) -> some View {
    HStack(alignment: .top, spacing: 0) {
      // Line number
      Text(lineNumber(for: line, side: side))
        .font(.system(size: Constants.fontSize - 1, design: .monospaced))
        .foregroundColor(.secondary)
        .frame(width: Constants.lineNumberWidth, alignment: .trailing)
        .padding(.trailing, 8)
        .background(Color.gray.opacity(0.1))
      
      // Content
      if shouldShowContent(for: line, side: side) {
        Text(line.content)
          .font(.system(size: Constants.fontSize, design: .monospaced))
          .foregroundColor(contentColor(for: line, side: side))
          .padding(.horizontal, 4)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
      } else {
        // Empty space for alignment
        Text(" ")
          .font(.system(size: Constants.fontSize, design: .monospaced))
          .padding(.horizontal, 4)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .background(backgroundColor(for: line, side: side))
  }
  
  private func lineNumber(for line: SyncedLine, side: ColumnSide) -> String {
    switch side {
    case .left:
      return line.oldLineNumber.map(String.init) ?? ""
    case .right:
      return line.newLineNumber.map(String.init) ?? ""
    }
  }
  
  private func shouldShowContent(for line: SyncedLine, side: ColumnSide) -> Bool {
    switch (line.type, side) {
    case (.unchanged, _):
      return true
    case (.added, .right):
      return true
    case (.removed, .left):
      return true
    default:
      return false
    }
  }
  
  private func backgroundColor(for line: SyncedLine, side: ColumnSide) -> Color {
    switch (line.type, side) {
    case (.added, .right):
      return colorScheme.addedLineDiffBackground
    case (.removed, .left):
      return colorScheme.removedLineDiffBackground
    case (.added, .left), (.removed, .right):
      return Color.gray.opacity(0.05) // Placeholder background
    default:
      return Color.clear
    }
  }
  
  private func contentColor(for line: SyncedLine, side: ColumnSide) -> Color {
    switch line.type {
    case .added:
      return colorScheme == .dark ? .green.opacity(0.9) : .green.opacity(0.8)
    case .removed:
      return colorScheme == .dark ? .red.opacity(0.9) : .red.opacity(0.8)
    case .unchanged:
      return .primary
    }
  }
  
  /// Process the diff lines to create synchronized lines for side-by-side display
  private func processSynchronizedLines() -> [SyncedLine] {
    var result: [SyncedLine] = []
    
    for line in formattedDiff.changes {
      let syncedLine = SyncedLine(
        id: UUID(),
        content: line.change.content,
        oldLineNumber: line.change.oldLineNumber,
        newLineNumber: line.change.newLineNumber,
        type: line.change.type
      )
      result.append(syncedLine)
    }
    
    return result
  }
}

// MARK: - Supporting Types

private enum ColumnSide {
  case left
  case right
}

private struct SyncedLine: Identifiable {
  let id: UUID
  let content: String
  let oldLineNumber: Int?
  let newLineNumber: Int?
  let type: DiffContentType
}