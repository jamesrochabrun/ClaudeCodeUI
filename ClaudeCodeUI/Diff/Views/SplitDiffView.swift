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
    static let fontSize: CGFloat = 13
    static let lineNumberWidth: CGFloat = 40
    static let cornerRadius: CGFloat = 4
    static let lineHeight: CGFloat = 20
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
        .foregroundColor(lineNumberColor(for: line, side: side))
        .frame(width: Constants.lineNumberWidth, alignment: .trailing)
        .padding(.trailing, 8)
        .background(lineNumberBackground())
      
      // Content with enhanced styling
      if shouldShowContent(for: line, side: side) {
        Text(line.content)
          .font(.system(size: Constants.fontSize, design: .monospaced))
          .foregroundColor(contentTextColor(for: line, side: side))
          .padding(.vertical, 2)
          .padding(.horizontal, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .fixedSize(horizontal: false, vertical: true)
          .textSelection(.enabled)
          .background(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
              .fill(contentBackground(for: line, side: side))
              .opacity(shouldHighlight(for: line, side: side) ? 1 : 0)
          )
          .overlay(
            RoundedRectangle(cornerRadius: Constants.cornerRadius)
              .strokeBorder(contentBorder(for: line, side: side), lineWidth: 1)
              .opacity(shouldHighlight(for: line, side: side) ? 0.3 : 0)
          )
      } else {
        // Empty space for alignment
        Text(" ")
          .font(.system(size: Constants.fontSize, design: .monospaced))
          .padding(.vertical, 2)
          .padding(.horizontal, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .frame(minHeight: Constants.lineHeight)
    .background(rowBackground(for: line, side: side))
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
  
  // MARK: - Styling Helpers
  
  private func shouldHighlight(for line: SyncedLine, side: ColumnSide) -> Bool {
    switch (line.type, side) {
    case (.added, .right), (.removed, .left):
      return true
    default:
      return false
    }
  }
  
  private func lineNumberColor(for line: SyncedLine, side: ColumnSide) -> Color {
    guard shouldShowContent(for: line, side: side) else {
      return .secondary.opacity(0.3)
    }
    
    switch line.type {
    case .added:
      return colorScheme == .dark ? Color.green.opacity(0.8) : Color.green.opacity(0.7)
    case .removed:
      return colorScheme == .dark ? Color.red.opacity(0.8) : Color.red.opacity(0.7)
    case .unchanged:
      return .secondary.opacity(0.7)
    }
  }
  
  private func lineNumberBackground() -> Color {
    colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.05)
  }
  
  private func contentBackground(for line: SyncedLine, side: ColumnSide) -> Color {
    switch (line.type, side) {
    case (.added, .right):
      return colorScheme == .dark ? Color.green.opacity(0.15) : Color.green.opacity(0.12)
    case (.removed, .left):
      return colorScheme == .dark ? Color.red.opacity(0.15) : Color.red.opacity(0.12)
    case (.added, .left), (.removed, .right):
      return Color.gray.opacity(0.05) // Placeholder background
    default:
      return .clear
    }
  }
  
  private func contentBorder(for line: SyncedLine, side: ColumnSide) -> Color {
    switch (line.type, side) {
    case (.added, .right):
      return colorScheme == .dark ? Color.green.opacity(0.5) : Color.green.opacity(0.3)
    case (.removed, .left):
      return colorScheme == .dark ? Color.red.opacity(0.5) : Color.red.opacity(0.3)
    default:
      return .clear
    }
  }
  
  private func contentTextColor(for line: SyncedLine, side: ColumnSide) -> Color {
    guard shouldShowContent(for: line, side: side) else {
      return .clear
    }
    
    switch line.type {
    case .added, .removed:
      return colorScheme == .dark ? .primary : .primary.opacity(0.9)
    case .unchanged:
      return .primary.opacity(0.8)
    }
  }
  
  private func rowBackground(for line: SyncedLine, side: ColumnSide) -> Color {
    switch (line.type, side) {
    case (.added, .right):
      return colorScheme == .dark ? Color.green.opacity(0.05) : Color.green.opacity(0.02)
    case (.removed, .left):
      return colorScheme == .dark ? Color.red.opacity(0.05) : Color.red.opacity(0.02)
    case (.added, .left), (.removed, .right):
      return Color.gray.opacity(0.02) // Subtle placeholder
    default:
      return .clear
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
