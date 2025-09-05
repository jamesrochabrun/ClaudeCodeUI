import Foundation
import SwiftUI

// MARK: - DiffContainerView

struct DiffContainerView<SlotContent: View>: View {

  // MARK: Lifecycle

  init(
    group: DiffTerminalService.DiffGroup,
    filePath: String,
    isApplied: Bool,
    @ViewBuilder slotContent: () -> SlotContent
  ) {
    self.group = group
    self.filePath = filePath
    self.isApplied = isApplied
    self.slotContent = slotContent()
  }

  // MARK: Internal

  let group: DiffTerminalService.DiffGroup

  let filePath: String

  let isApplied: Bool

  var topBarTrailingContent: some View {
    HStack {
      AnimatedCopyButton(textToCopy: group.formattedString, title: "Copy")
        .clickThrough()
        .buttonStyle(.plain)
        .padding(.trailing, 8)
    }
    .padding(.trailing, 8)
  }

  /// Updated topBar view with line count indicators
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
        topBarTrailingContent
      }
    }
    .padding(.vertical, 4)
  }

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // if group.lines is empty, means we are dealing with a new file.
      if !group.lines.isEmpty {
        topBar
        Divider()
          .padding(.bottom, 4)
      }
      slotContent
      Divider()
        .padding(.vertical, 8)
    }
    .padding(4)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(isApplied ? Color.green.opacity(0.5) : Color.clear, lineWidth: 2)
    )
    .animation(.spring, value: isApplied)
  }

  // MARK: Private

  @Environment(\.colorScheme) private var colorScheme

  /// Custom content provided via a ViewBuilder closure.
  private let slotContent: SlotContent

  private var buttonBackgroundColor: Color {
    isApplied ? Color.orange.opacity(0.7) : Color.blue.opacity(0.7)
  }

  private var linesAdded: Int {
    group.lines.count(where: { $0.type == .inserted })
  }

  private var linesRemoved: Int {
    group.lines.count(where: { $0.type == .deleted })
  }
}
