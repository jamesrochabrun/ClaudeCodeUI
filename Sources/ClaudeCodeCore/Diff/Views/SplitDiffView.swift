//
//  SplitDiffView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import SwiftUI

/// A SwiftUI view that displays file diffs in a side-by-side (split) format.
///
/// `SplitDiffView` presents code changes by showing the original content on the left
/// and the modified content on the right, making it easy to compare changes visually.
/// This is commonly used in version control systems and code review tools.
///
/// ## Features
/// - Side-by-side comparison of original and modified code
/// - Synchronized scrolling between columns
/// - Color-coded line additions and removals
/// - Line number display for both versions
/// - Support for light and dark color schemes
/// - Text selection support for copying content
///
/// ## Usage
/// ```swift
/// SplitDiffView(formattedDiff: myFormattedFileChange)
/// ```
///
/// The view automatically handles:
/// - Empty space alignment for added/removed lines
/// - Highlighting of changed lines
/// - Responsive layout that expands to available width
struct SplitDiffView: View {
  /// The formatted file change data containing the diff information to display
  let formattedDiff: FormattedFileChange
  
  /// The current color scheme (light/dark) used for adaptive styling
  @Environment(\.colorScheme) private var colorScheme
  
  /// UI constants for consistent styling throughout the view
  private enum Constants {
    /// Font size for code content
    static let fontSize: CGFloat = 13
    /// Fixed width for line number columns
    static let lineNumberWidth: CGFloat = 40
    /// Corner radius for highlighted line backgrounds
    static let cornerRadius: CGFloat = 4
    /// Minimum height for each line row
    static let lineHeight: CGFloat = 20
  }
  
  /// Computed property that returns synchronized lines for side-by-side display
  /// This processes the raw diff data into a format suitable for split view
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
  
  /// Creates a column view for either the left (original) or right (modified) side
  /// - Parameter side: The column side to render (.left or .right)
  /// - Returns: A VStack containing all lines for the specified side
  @ViewBuilder
  private func column(side: ColumnSide) -> some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(syncedLines) { line in
        lineView(for: line, side: side)
      }
    }
    .frame(maxWidth: .infinity)
  }
  
  /// Creates a single line view with line number and content
  /// - Parameters:
  ///   - line: The synchronized line data to display
  ///   - side: The column side being rendered
  /// - Returns: An HStack containing the line number and content
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
  
  /// Determines the appropriate line number to display for a given side
  /// - Parameters:
  ///   - line: The synchronized line containing line numbers
  ///   - side: The column side to get the line number for
  /// - Returns: The line number as a string, or empty string if not applicable
  private func lineNumber(for line: SyncedLine, side: ColumnSide) -> String {
    switch side {
    case .left:
      return line.oldLineNumber.map(String.init) ?? ""
    case .right:
      return line.newLineNumber.map(String.init) ?? ""
    }
  }
  
  /// Determines whether content should be displayed for a line on a specific side
  /// - Parameters:
  ///   - line: The synchronized line to check
  ///   - side: The column side to check
  /// - Returns: true if content should be shown, false for placeholder space
  /// - Note: 
  ///   - Unchanged lines appear on both sides
  ///   - Added lines only appear on the right
  ///   - Removed lines only appear on the left
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
  
  /// Determines if a line should be highlighted with a background color
  /// - Parameters:
  ///   - line: The line to check for highlighting
  ///   - side: The column side being rendered
  /// - Returns: true if the line should be highlighted
  /// - Note: Highlights added lines on the right and removed lines on the left
  private func shouldHighlight(for line: SyncedLine, side: ColumnSide) -> Bool {
    switch (line.type, side) {
    case (.added, .right), (.removed, .left):
      return true
    default:
      return false
    }
  }
  
  /// Determines the color for line numbers based on the line type and visibility
  /// - Parameters:
  ///   - line: The line whose number color is being determined
  ///   - side: The column side for context
  /// - Returns: Appropriate color for the line number
  /// - Note: Uses green for additions, red for removals, and gray for unchanged
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
  
  /// Provides the background color for the line number column
  /// - Returns: A subtle background color adapted to the current color scheme
  private func lineNumberBackground() -> Color {
    colorScheme == .dark ? Color.black.opacity(0.2) : Color.gray.opacity(0.05)
  }
  
  /// Determines the background color for content based on line type and side
  /// - Parameters:
  ///   - line: The line whose background is being styled
  ///   - side: The column side being rendered
  /// - Returns: Background color for the content area
  /// - Note: 
  ///   - Green background for additions on the right
  ///   - Red background for removals on the left
  ///   - Gray placeholder for empty alignment spaces
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
  
  /// Determines the border color for highlighted content
  /// - Parameters:
  ///   - line: The line whose border is being styled
  ///   - side: The column side being rendered
  /// - Returns: Border color for the content area
  /// - Note: Only returns visible colors for added/removed lines on their respective sides
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
  
  /// Determines the text color for content based on line type
  /// - Parameters:
  ///   - line: The line whose text color is being determined
  ///   - side: The column side for visibility check
  /// - Returns: Appropriate text color for the content
  /// - Note: Uses slightly muted colors for unchanged lines
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
  
  /// Provides a subtle row background color for better visual separation
  /// - Parameters:
  ///   - line: The line whose row background is being styled
  ///   - side: The column side being rendered
  /// - Returns: A very subtle background color for the entire row
  /// - Note: Complements the content background with lighter tints
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
  
  /// Processes the formatted diff data into synchronized lines for side-by-side display
  /// - Returns: Array of SyncedLine objects ready for rendering
  /// - Note: This method transforms the linear diff format into a format suitable
  ///         for side-by-side comparison, maintaining line alignment between columns
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

/// Represents which side of the split view a column belongs to
private enum ColumnSide {
  /// The left column showing original content
  case left
  /// The right column showing modified content
  case right
}

/// Represents a synchronized line in the split diff view
/// 
/// This structure holds all the information needed to render a single line
/// in both columns of the split view, including line numbers for both versions
/// and the type of change (added, removed, or unchanged).
private struct SyncedLine: Identifiable {
  /// Unique identifier for SwiftUI ForEach
  let id: UUID
  /// The actual line content to display
  let content: String
  /// Line number in the original file (nil for added lines)
  let oldLineNumber: Int?
  /// Line number in the modified file (nil for removed lines)
  let newLineNumber: Int?
  /// The type of change this line represents
  let type: DiffContentType
}
