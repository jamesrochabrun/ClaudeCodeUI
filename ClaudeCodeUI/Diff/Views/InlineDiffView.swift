//
//  InlineDiffView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//


import SwiftUI

/// GitHub-style inline diff view showing changes in a single column
struct InlineDiffView: View {
  let formattedDiff: FormattedFileChange
  
  @Environment(\.colorScheme) private var colorScheme
  
  private enum Constants {
    static let fontSize: CGFloat = 11
    static let lineNumberWidth: CGFloat = 60
    static let changeIndicatorWidth: CGFloat = 20
  }
  
  private var changedLines: [FormattedLineChange] {
    formattedDiff.changes
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(Array(changedLines.enumerated()), id: \.offset) { index, formattedLine in
        lineView(for: formattedLine, at: index)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
  }
  
  @ViewBuilder
  private func lineView(for line: FormattedLineChange, at index: Int) -> some View {
    HStack(alignment: .top, spacing: 0) {
      // Line number - only show for non-deleted lines
      HStack(spacing: 0) {
        Text(lineNumber(for: line))
          .font(.system(size: Constants.fontSize - 1, design: .monospaced))
          .foregroundColor(.secondary)
          .frame(width: Constants.lineNumberWidth, alignment: .trailing)
          .padding(.trailing, 8)
      }
      .background(Color.gray.opacity(0.1))
      
      // Change indicator
      Text(changeIndicator(for: line))
        .font(.system(size: Constants.fontSize, design: .monospaced))
        .foregroundColor(changeColor(for: line))
        .frame(width: Constants.changeIndicatorWidth)
        .padding(.horizontal, 2)
      
      // Content
      Text(line.formattedContent)
        .font(.system(size: Constants.fontSize, design: .monospaced))
        .foregroundColor(contentColor(for: line))
        .padding(.horizontal, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
    .background(backgroundColor(for: line))
  }
  
  private func lineNumber(for line: FormattedLineChange) -> String {
    // For inline view, show the new line number (or old for deletions)
    if let newLine = line.change.newLineNumber {
      return String(newLine)
    } else if let oldLine = line.change.oldLineNumber {
      return String(oldLine)
    }
    return ""
  }
  
  private func backgroundColor(for line: FormattedLineChange) -> Color {
    switch line.change.type {
    case .added:
      return colorScheme.addedLineDiffBackground
    case .removed:
      return colorScheme.removedLineDiffBackground
    case .unchanged:
      return Color.clear
    }
  }
  
  private func changeIndicator(for line: FormattedLineChange) -> String {
    switch line.change.type {
    case .added:
      return "+"
    case .removed:
      return "-"
    case .unchanged:
      return " "
    }
  }
  
  private func changeColor(for line: FormattedLineChange) -> Color {
    switch line.change.type {
    case .added:
      return .green
    case .removed:
      return .red
    case .unchanged:
      return .secondary
    }
  }
  
  private func contentColor(for line: FormattedLineChange) -> Color {
    switch line.change.type {
    case .added:
      return colorScheme == .dark ? .green.opacity(0.9) : .green.opacity(0.8)
    case .removed:
      return colorScheme == .dark ? .red.opacity(0.9) : .red.opacity(0.8)
    case .unchanged:
      return .primary
    }
  }
}

// MARK: - Preview

#Preview {
  InlineDiffView(formattedDiff: .preview)
    .frame(width: 800, height: 600)
    .padding()
}

// MARK: - Preview Data

extension FormattedFileChange {
  static let preview: FormattedFileChange = {
    let changes: [FormattedLineChange] = [
      // Context before
      FormattedLineChange(
        formattedContent: AttributedString("import SwiftUI"),
        change: LineChange(
          oldLineNumber: 1,
          newLineNumber: 1,
          characterRange: 0..<14,
          content: "import SwiftUI",
          type: .unchanged
        )
      ),
      FormattedLineChange(
        formattedContent: AttributedString("import Foundation"),
        change: LineChange(
          oldLineNumber: 2,
          newLineNumber: 2,
          characterRange: 0..<17,
          content: "import Foundation",
          type: .unchanged
        )
      ),
      FormattedLineChange(
        formattedContent: AttributedString(""),
        change: LineChange(
          oldLineNumber: 3,
          newLineNumber: 3,
          characterRange: 0..<0,
          content: "",
          type: .unchanged
        )
      ),
      
      // Removed line
      FormattedLineChange(
        formattedContent: AttributedString("struct OldView: View {"),
        change: LineChange(
          oldLineNumber: 4,
          newLineNumber: nil,
          characterRange: 0..<22,
          content: "struct OldView: View {",
          type: .removed
        )
      ),
      
      // Added lines
      FormattedLineChange(
        formattedContent: AttributedString("struct NewView: View {"),
        change: LineChange(
          oldLineNumber: nil,
          newLineNumber: 4,
          characterRange: 0..<22,
          content: "struct NewView: View {",
          type: .added
        )
      ),
      FormattedLineChange(
        formattedContent: AttributedString("    @State private var count = 0"),
        change: LineChange(
          oldLineNumber: nil,
          newLineNumber: 5,
          characterRange: 0..<32,
          content: "    @State private var count = 0",
          type: .added
        )
      ),
      FormattedLineChange(
        formattedContent: AttributedString("    "),
        change: LineChange(
          oldLineNumber: nil,
          newLineNumber: 6,
          characterRange: 0..<4,
          content: "    ",
          type: .added
        )
      ),
      
      // Unchanged context
      FormattedLineChange(
        formattedContent: AttributedString("    var body: some View {"),
        change: LineChange(
          oldLineNumber: 5,
          newLineNumber: 7,
          characterRange: 0..<25,
          content: "    var body: some View {",
          type: .unchanged
        )
      ),
      
      // Modified lines (shown as remove + add)
      FormattedLineChange(
        formattedContent: AttributedString("        Text(\"Hello, World!\")"),
        change: LineChange(
          oldLineNumber: 6,
          newLineNumber: nil,
          characterRange: 0..<29,
          content: "        Text(\"Hello, World!\")",
          type: .removed
        )
      ),
      FormattedLineChange(
        formattedContent: AttributedString("        VStack {"),
        change: LineChange(
          oldLineNumber: nil,
          newLineNumber: 8,
          characterRange: 0..<16,
          content: "        VStack {",
          type: .added
        )
      ),
      FormattedLineChange(
        formattedContent: AttributedString("            Text(\"Count: \\(count)\")"),
        change: LineChange(
          oldLineNumber: nil,
          newLineNumber: 9,
          characterRange: 0..<34,
          content: "            Text(\"Count: \\(count)\")",
          type: .added
        )
      ),
      FormattedLineChange(
        formattedContent: AttributedString("            Button(\"Increment\") {"),
        change: LineChange(
          oldLineNumber: nil,
          newLineNumber: 10,
          characterRange: 0..<33,
          content: "            Button(\"Increment\") {",
          type: .added
        )
      ),
      FormattedLineChange(
        formattedContent: AttributedString("                count += 1"),
        change: LineChange(
          oldLineNumber: nil,
          newLineNumber: 11,
          characterRange: 0..<26,
          content: "                count += 1",
          type: .added
        )
      ),
      FormattedLineChange(
        formattedContent: AttributedString("            }"),
        change: LineChange(
          oldLineNumber: nil,
          newLineNumber: 12,
          characterRange: 0..<13,
          content: "            }",
          type: .added
        )
      ),
      FormattedLineChange(
        formattedContent: AttributedString("        }"),
        change: LineChange(
          oldLineNumber: nil,
          newLineNumber: 13,
          characterRange: 0..<9,
          content: "        }",
          type: .added
        )
      ),
      
      // More context
      FormattedLineChange(
        formattedContent: AttributedString("    }"),
        change: LineChange(
          oldLineNumber: 7,
          newLineNumber: 14,
          characterRange: 0..<5,
          content: "    }",
          type: .unchanged
        )
      ),
      FormattedLineChange(
        formattedContent: AttributedString("}"),
        change: LineChange(
          oldLineNumber: 8,
          newLineNumber: 15,
          characterRange: 0..<1,
          content: "}",
          type: .unchanged
        )
      )
    ]
    
    return FormattedFileChange(changes: changes)
  }()
}
