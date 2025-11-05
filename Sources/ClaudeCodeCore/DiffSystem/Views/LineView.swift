import Foundation
import SwiftUI

// MARK: - LineView

struct LineView: View {

  // MARK: Internal

  let line: DiffTerminalService.DiffLine

  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 0) {
      LineNumberView(lineNumber: line.lineNumber)
      LineContentView(text: line.text)
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(lineBackgroundColor)
  }

  // MARK: Private

  @Environment(\.colorScheme) private var colorScheme

  private var lineBackgroundColor: Color {
    switch line.type {
    case .inserted:
      DiffColors.backgroundColorForAddedLines(in: colorScheme)
    case .deleted:
      DiffColors.backgroundColorForRemovedLines(in: colorScheme)
    case .unchanged:
      .clear
    }
  }
}

// MARK: - LineNumberView

private struct LineNumberView: View {
  let lineNumber: Int?

  var body: some View {
    if let lineNumber {
      Text("\(lineNumber)")
        .font(.system(.body, design: .monospaced))
        .fontWeight(.light)
        .padding(.trailing, 6)
    } else {
      // For deleted lines or separator lines, we don't show a line number
      Text("")
        .frame(width: 22, alignment: .leading)
    }
  }
}

// MARK: - LineContentView

private struct LineContentView: View {
  let text: String

  var body: some View {
    Text(text)
      .textSelection(.enabled)
      .font(.system(.body, design: .monospaced))
      .fontWeight(.light)
      .padding(.vertical, 2)
      .padding(.horizontal, 4)
      .cornerRadius(2)
  }
}

// MARK: - Previews

#Preview("Diff Lines") {
  VStack(alignment: .leading, spacing: 0) {
    LineView(line: .init(text: "func example() {", type: .unchanged, lineNumber: 10))
    LineView(line: .init(text: "  // Old comment", type: .deleted, lineNumber: nil))
    LineView(line: .init(text: "  // New improved comment", type: .inserted, lineNumber: 11))
    LineView(line: .init(text: "  let value = 42", type: .unchanged, lineNumber: 12))
    LineView(line: .init(text: "}", type: .unchanged, lineNumber: 13))
  }
  .padding()
}
