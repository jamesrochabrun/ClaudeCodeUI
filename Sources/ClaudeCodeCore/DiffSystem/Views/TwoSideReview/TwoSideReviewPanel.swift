import Foundation
import SwiftUI

// MARK: - TwoSideReviewPanel

struct TwoSideReviewPanel: View {
  
  // MARK: - Initialization
  
  init(
    group: ApplyChangesPreviewContentGenerator.DiffGroup,
    isApplied: Bool,
    onReviewTap: (() -> Void)? = nil
  ) {
    self.group = group
    self.isApplied = isApplied
    self.onReviewTap = onReviewTap
  }
  
  // MARK: Internal
  
  /// The group of diff lines to display
  let group: ApplyChangesPreviewContentGenerator.DiffGroup
  
  /// Whether this diff has been applied
  let isApplied: Bool
  
  /// Optional action for review button
  let onReviewTap: (() -> Void)?
  
  var topBar: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Spacer()
        // Add line count indicators
        if linesRemoved > 0 {
          Text("-\(linesRemoved)")
            .font(.caption)
            .fontDesign(.monospaced)
            .foregroundColor(.red)
            .padding(.horizontal, 2)
        }
        
        if linesAdded > 0 {
          Text("+\(linesAdded)")
            .font(.caption)
            .fontDesign(.monospaced)
            .foregroundColor(.green)
            .padding(.horizontal, 2)
        }
      }
    }
    .padding(.vertical, 4)
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if !group.lines.isEmpty {
        topBar
        Divider()
          .padding(.bottom, 4)
      }
      splitContent
      
      Divider()
        .padding(.vertical, 4)
    }
    .roundBorder(cornerRadius: 12)
    .animation(.spring, value: isApplied)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(isApplied ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
    )
    .onAppear {
      // Process lines only once when view appears
      if syncedLines.isEmpty {
        syncedLines = processSynchronizedLines()
      }
    }
    .onChange(of: group) { _ in
      // Reprocess only when the data changes
      syncedLines = processSynchronizedLines()
    }
  }
  
  // MARK: Private
  
  // MARK: - State
  
  /// Processed synchronized lines (computed once)
  @State private var syncedLines = [SynchronizedLine]()
  
  @Environment(\.colorScheme) private var colorScheme
    
  private var linesAdded: Int {
    group.lines.count(where: { $0.type == .inserted })
  }
  
  private var linesRemoved: Int {
    group.lines.count(where: { $0.type == .deleted })
  }
  
  /// The main split view content showing original and updated code side by side
  private var splitContent: some View {
    HStack(alignment: .top, spacing: 0) {
      column(side: .left)
      
      // Divider line between columns
      Rectangle()
        .fill(Color.gray.opacity(0.3))
        .frame(width: 1)
      
      column(side: .right)
    }
    .overlay(alignment: .topTrailing) {
      AnimatedCopyButton(textToCopy: group.formattedString, title: "Copy")
        .clickThrough()
        .buttonStyle(.plain)
        .padding(5)
        .background(.ultraThinMaterial)
    }
  }
  
  /// Background color for the apply/revert button
  private var buttonBackgroundColor: Color {
    isApplied ? Color.orange.opacity(0.7) : Color.blue.opacity(0.7)
  }
  
  /// Column displaying code for a particular side
  private func column(side: ViewSide) -> some View {
    LazyVStack(alignment: .leading, spacing: 0) {
      ForEach(syncedLines.indices, id: \.self) { index in
        SyncedLineView(
          syncedLine: syncedLines[index],
          side: side
        )
        .id("\(side)-\(index)") // Stable ID for better diffing
      }
    }
    .frame(maxWidth: .infinity)
  }
  
  /// Process group lines into synchronized lines for both columns
  private func processSynchronizedLines() -> [SynchronizedLine] {
    var result = [SynchronizedLine]()
    var originalLineNumber = 0
    var updatedLineNumber = 0
    
    // Find the starting line numbers
    let startOriginalLine = group.lines.first(where: {
      $0.type == .unchanged || $0.type == .deleted
    })?.lineNumber ?? 1
    
    let startUpdatedLine = group.lines.first(where: {
      $0.type == .unchanged || $0.type == .inserted
    })?.lineNumber ?? 1
    
    originalLineNumber = startOriginalLine
    updatedLineNumber = startUpdatedLine
    
    for (index, line) in group.lines.enumerated() {
      var syncedLine: SynchronizedLine
      
      switch line.type {
      case .unchanged:
        syncedLine = SynchronizedLine(
          id: "u-\(index)",
          text: line.text,
          originalLineNumber: line.lineNumber,
          updatedLineNumber: line.lineNumber,
          type: .unchanged
        )
        originalLineNumber = (line.lineNumber ?? originalLineNumber) + 1
        updatedLineNumber = (line.lineNumber ?? updatedLineNumber) + 1
        
      case .deleted:
        syncedLine = SynchronizedLine(
          id: "d-\(index)",
          text: line.text,
          originalLineNumber: originalLineNumber,
          updatedLineNumber: nil,
          type: .deleted
        )
        originalLineNumber += 1
        
      case .inserted:
        syncedLine = SynchronizedLine(
          id: "i-\(index)",
          text: line.text,
          originalLineNumber: nil,
          updatedLineNumber: updatedLineNumber,
          type: .inserted
        )
        updatedLineNumber += 1
      }
      
      result.append(syncedLine)
    }
    
    return result
  }
}

// MARK: - SynchronizedLine

/// Model for synchronized line display that keeps left and right sides in sync
struct SynchronizedLine: Identifiable {
  let id: String
  let text: String
  let originalLineNumber: Int?
  let updatedLineNumber: Int?
  let type: ApplyChangesPreviewContentGenerator.DiffType
}

// MARK: - ViewSide

enum ViewSide {
  case left
  case right
}

// MARK: - SyncedLineView

/// View that displays a single line in the synchronized split view
struct SyncedLineView: View {
  
  // MARK: Internal
  
  let syncedLine: SynchronizedLine
  let side: ViewSide
  
  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 0) {
      // Line number column
      if let lineNumber = (side == .left ? syncedLine.originalLineNumber : syncedLine.updatedLineNumber) {
        Text("\(lineNumber)")
          .font(.system(.body, design: .monospaced))
          .foregroundColor(.gray)
          .frame(width: 40, alignment: side == .left ? .leading : .trailing)
          .padding(.horizontal, 4)
      } else {
        // No line number for placeholders
        Text("")
          .frame(width: 40, alignment: .leading)
          .padding(.horizontal, 4)
      }
      
      // Line content - always show the text for synchronization
      // but hide it with opacity when it's not applicable to this side
      Text(syncedLine.text)
        .textSelection(.enabled)
        .font(.system(.body, design: .monospaced))
        .padding(.vertical, 2)
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(shouldShowText ? 1 : 0) // Hide text but preserve layout
        .background(shouldShowBackground ? backgroundColor : .clear)
    }
  }
  
  // MARK: Private
  
  @Environment(\.colorScheme) private var colorScheme
  
  /// Determines if this side should show the text
  private var shouldShowText: Bool {
    switch (syncedLine.type, side) {
    case (.unchanged, _):
      true
    case (.deleted, .left):
      true
    case (.inserted, .right):
      true
    default:
      false
    }
  }
  
  /// Determines if this side should show the background color
  private var shouldShowBackground: Bool {
    switch (syncedLine.type, side) {
    case (.unchanged, _):
      false
    case (.deleted, .left):
      true
    case (.inserted, .right):
      true
    case (.deleted, .right), (.inserted, .left):
      true // Show gray placeholder background
    default:
      false
    }
  }
  
  /// Background color based on the line type and side
  private var backgroundColor: Color {
    switch (syncedLine.type, side) {
    case (.deleted, .left):
      DiffColors.backgroundColorForRemovedLines(in: colorScheme)
    case (.inserted, .right):
      DiffColors.backgroundColorForAddedLines(in: colorScheme)
    case (.deleted, .right), (.inserted, .left):
      Color.gray.opacity(0.15) // Gray placeholder
    default:
        .clear
    }
  }
}
