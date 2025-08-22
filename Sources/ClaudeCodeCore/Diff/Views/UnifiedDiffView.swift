//
//  UnifiedDiffView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import SwiftUI

/// Container view that provides toggle between inline and split diff views
public struct UnifiedDiffView: View {
  let formattedDiff: FormattedFileChange?
  let fileName: String?
  
  @State private var viewMode: DiffViewMode = .inline
  @Environment(\.colorScheme) private var colorScheme
  
  private enum DiffViewMode: String, CaseIterable {
    case inline = "Inline"
    case split = "Split"
    
    var icon: String {
      switch self {
      case .inline:
        return "text.alignleft"
      case .split:
        return "rectangle.split.2x1"
      }
    }
  }
  
  public init(formattedDiff: FormattedFileChange?, fileName: String? = nil) {
    self.formattedDiff = formattedDiff
    self.fileName = fileName
  }
  
  private var changedLines: [FormattedLineChange] {
    formattedDiff?.changes ?? []
  }
  
  private var statistics: (additions: Int, deletions: Int) {
    let additions = changedLines.filter { $0.change.type == .added }.count
    let deletions = changedLines.filter { $0.change.type == .removed }.count
    return (additions, deletions)
  }
  
  public var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Header with toggle
      diffHeader
      
      // Content based on selected mode
      if let formattedDiff = formattedDiff {
        Group {
          switch viewMode {
          case .inline:
            InlineDiffView(formattedDiff: formattedDiff)
          case .split:
            SplitDiffView(formattedDiff: formattedDiff)
          }
        }
        .background(colorScheme.xcodeEditorBackground)
        .cornerRadius(4)
      }
    }
  }
  
  @ViewBuilder
  private var diffHeader: some View {
    HStack {
      // File info
      if let fileName = fileName {
        Label(fileName, systemImage: "doc.text")
          .font(.system(.body, design: .monospaced))
      } else {
        Text("Diff")
          .font(.system(.body, design: .monospaced))
      }
      
      // Statistics
      let stats = statistics
      HStack(spacing: 8) {
        Text("+\(stats.additions)")
          .foregroundColor(.green)
          .font(.system(size: 12, weight: .medium, design: .monospaced))
        
        Text("-\(stats.deletions)")
          .foregroundColor(.red)
          .font(.system(size: 12, weight: .medium, design: .monospaced))
      }
      .padding(.horizontal, 8)
      
      Spacer()
      
      // View mode toggle
      Picker("View Mode", selection: $viewMode) {
        ForEach(DiffViewMode.allCases, id: \.self) { mode in
          Label(mode.rawValue, systemImage: mode.icon)
            .tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .fixedSize()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(4)
  }
}

#Preview {
  VStack(spacing: 20) {
    // Example with inline diff
    UnifiedDiffView(
      formattedDiff: FormattedFileChange(
        changes: [
          FormattedLineChange(
            formattedContent: AttributedString("func calculateTotal() {"),
            change: LineChange(
              oldLineNumber: 1,
              newLineNumber: 1,
              characterRange: 0..<23,
              content: "func calculateTotal() {",
              type: .unchanged
            )
          ),
          FormattedLineChange(
            formattedContent: AttributedString("    return price * quantity"),
            change: LineChange(
              oldLineNumber: 2,
              newLineNumber: nil,
              characterRange: 0..<27,
              content: "    return price * quantity",
              type: .removed
            )
          ),
          FormattedLineChange(
            formattedContent: AttributedString("    let subtotal = price * quantity"),
            change: LineChange(
              oldLineNumber: nil,
              newLineNumber: 2,
              characterRange: 0..<35,
              content: "    let subtotal = price * quantity",
              type: .added
            )
          ),
          FormattedLineChange(
            formattedContent: AttributedString("    let tax = subtotal * 0.08"),
            change: LineChange(
              oldLineNumber: nil,
              newLineNumber: 3,
              characterRange: 0..<29,
              content: "    let tax = subtotal * 0.08",
              type: .added
            )
          ),
          FormattedLineChange(
            formattedContent: AttributedString("    return subtotal + tax"),
            change: LineChange(
              oldLineNumber: nil,
              newLineNumber: 4,
              characterRange: 0..<25,
              content: "    return subtotal + tax",
              type: .added
            )
          ),
          FormattedLineChange(
            formattedContent: AttributedString("}"),
            change: LineChange(
              oldLineNumber: 3,
              newLineNumber: 5,
              characterRange: 0..<1,
              content: "}",
              type: .unchanged
            )
          )
        ]
      ),
      fileName: "ShoppingCart.swift"
    )
    
    // Example with no changes
    UnifiedDiffView(
      formattedDiff: nil,
      fileName: "EmptyDiff.swift"
    )
  }
  .padding()
  .frame(maxWidth: .infinity, maxHeight: .infinity)
  .background(Color(NSColor.windowBackgroundColor))
}
