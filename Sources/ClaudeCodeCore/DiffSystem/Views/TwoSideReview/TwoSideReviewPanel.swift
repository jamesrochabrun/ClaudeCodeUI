import Foundation
import SwiftUI

// MARK: - TwoSideReviewPanel

struct TwoSideReviewPanel: View {
  
  init(
    group: DiffTerminalService.DiffGroup,
    isApplied: Bool)
  {
    self.group = group
    self.isApplied = isApplied
  }
  
  let group: DiffTerminalService.DiffGroup
  let isApplied: Bool
  
  @State private var sideLines: [SideLine] = []
  @Environment(\.colorScheme) private var colorScheme
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if !group.lines.isEmpty {
        DiffTopBar(
          linesAdded: linesAdded,
          linesRemoved: linesRemoved
        )
        Divider()
          .padding(.bottom, 4)
      }
      
      SplitContentView(
        sideLines: sideLines,
        formattedString: group.formattedString
      )
      
      Divider()
        .padding(.vertical, 4)
    }
    .roundBorder(cornerRadius: 12)
    .animation(.spring, value: isApplied)
    .overlay(DiffBorderOverlay(isApplied: isApplied))
    .onAppear {
      if sideLines.isEmpty {
        sideLines = processSideLines()
      }
    }
    .onChange(of: group) { _ in
      sideLines = processSideLines()
    }
  }
  
  private var linesAdded: Int {
    group.lines.count(where: { $0.type == .inserted })
  }
  
  private var linesRemoved: Int {
    group.lines.count(where: { $0.type == .deleted })
  }
  
  private func processSideLines() -> [SideLine] {
    var result = [SideLine]()
    var originalLineNumber = 0
    var updatedLineNumber = 0
    
    let startOriginalLine = group.lines.first(where: {
      $0.type == .unchanged || $0.type == .deleted
    })?.lineNumber ?? 1
    
    let startUpdatedLine = group.lines.first(where: {
      $0.type == .unchanged || $0.type == .inserted
    })?.lineNumber ?? 1
    
    originalLineNumber = startOriginalLine
    updatedLineNumber = startUpdatedLine
    
    for (index, line) in group.lines.enumerated() {
      var syncedLine: SideLine
      
      switch line.type {
      case .unchanged:
        syncedLine = SideLine(
          id: "u-\(index)",
          text: line.text,
          originalLineNumber: line.lineNumber,
          updatedLineNumber: line.lineNumber,
          type: .unchanged
        )
        originalLineNumber = (line.lineNumber ?? originalLineNumber) + 1
        updatedLineNumber = (line.lineNumber ?? updatedLineNumber) + 1
        
      case .deleted:
        syncedLine = SideLine(
          id: "d-\(index)",
          text: line.text,
          originalLineNumber: originalLineNumber,
          updatedLineNumber: nil,
          type: .deleted
        )
        originalLineNumber += 1
        
      case .inserted:
        syncedLine = SideLine(
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


// MARK: - LineCountIndicators

private struct LineCountIndicators: View {
  let linesAdded: Int
  let linesRemoved: Int
  
  var body: some View {
    HStack(spacing: 8) {
      if linesRemoved > 0 {
        LineCountBadge(count: linesRemoved, type: .removed)
      }
      
      if linesAdded > 0 {
        LineCountBadge(count: linesAdded, type: .added)
      }
    }
  }
}

// MARK: - LineCountBadge

private struct LineCountBadge: View {
  enum BadgeType {
    case added
    case removed
    
    var color: Color {
      switch self {
      case .added: return .green
      case .removed: return .red
      }
    }
    
    var prefix: String {
      switch self {
      case .added: return "+"
      case .removed: return "-"
      }
    }
  }
  
  let count: Int
  let type: BadgeType
  
  var body: some View {
    Text("\(type.prefix)\(count)")
      .font(.caption)
      .fontDesign(.monospaced)
      .foregroundColor(type.color)
      .padding(.horizontal, 2)
  }
}

// MARK: - DiffTopBar

private struct DiffTopBar: View {
  let linesAdded: Int
  let linesRemoved: Int
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack {
        Spacer()
        LineCountIndicators(
          linesAdded: linesAdded,
          linesRemoved: linesRemoved
        )
      }
    }
    .padding(.vertical, 4)
  }
}

// MARK: - SplitDivider

private struct SplitDivider: View {
  var body: some View {
    Rectangle()
      .fill(Color.gray.opacity(0.3))
      .frame(width: 1)
  }
}

// MARK: - DiffColumn

private struct DiffColumn: View {
  let sideLines: [SideLine]
  let side: ViewSide
  
  var body: some View {
    LazyVStack(alignment: .leading, spacing: 0) {
      ForEach(sideLines.indices, id: \.self) { index in
        SideLineReviewPanel(
          sideLine: sideLines[index],
          side: side
        )
        .id("\(side)-\(index)")
      }
    }
    .frame(maxWidth: .infinity)
  }
}

// MARK: - SplitContentView

private struct SplitContentView: View {
  let sideLines: [SideLine]
  let formattedString: String
  
  var body: some View {
    HStack(alignment: .top, spacing: 0) {
      DiffColumn(sideLines: sideLines, side: .left)
      SplitDivider()
      DiffColumn(sideLines: sideLines, side: .right)
    }
    .overlay(alignment: .topTrailing) {
      CopyButtonOverlay(formattedString: formattedString)
    }
  }
}

// MARK: - CopyButtonOverlay

private struct CopyButtonOverlay: View {
  let formattedString: String
  
  var body: some View {
    AnimatedCopyButton(textToCopy: formattedString, title: "Copy")
      .clickThrough()
      .buttonStyle(.plain)
      .padding(5)
      .background(.ultraThinMaterial)
  }
}

// MARK: - DiffBorderOverlay

private struct DiffBorderOverlay: View {
  let isApplied: Bool
  
  var body: some View {
    RoundedRectangle(cornerRadius: 12)
      .stroke(
        isApplied ? Color.green.opacity(0.5) : Color.clear,
        lineWidth: 2
      )
  }
}
