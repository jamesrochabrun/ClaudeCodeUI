import SwiftUI
import TerminalServiceInterface

struct MultiEditToolDiffView: View {
  let edits: [[String: String]]
  let filePath: String
  let fontSize: Double
  let contentTextColor: Color
  let terminalService: TerminalService
  
  @State private var selectedEditIndex: Int? = nil
  @State private var showAllEdits = true
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      headerView
      
      // Edit selector
      if edits.count > 1 {
        editSelectorView
      }
      
      // Diff views
      ScrollView {
        VStack(alignment: .leading, spacing: 16) {
          if showAllEdits {
            // Show all edits
            ForEach(Array(edits.enumerated()), id: \.offset) { index, edit in
              if let oldString = edit["old_string"],
                 let newString = edit["new_string"] {
                editDiffSection(
                  index: index,
                  oldString: oldString,
                  newString: newString
                )
              }
            }
          } else if let selectedIndex = selectedEditIndex,
                    selectedIndex < edits.count,
                    let oldString = edits[selectedIndex]["old_string"],
                    let newString = edits[selectedIndex]["new_string"] {
            // Show selected edit
            editDiffSection(
              index: selectedIndex,
              oldString: oldString,
              newString: newString
            )
          }
        }
        .padding(.horizontal, 8)
      }
    }
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(8)
  }
  
  private var headerView: some View {
    HStack {
      Image(systemName: "doc.text.fill")
        .foregroundStyle(.blue)
      Text(URL(fileURLWithPath: filePath).lastPathComponent)
        .font(.system(size: fontSize, weight: .medium))
      Spacer()
      Label("\(edits.count) edits", systemImage: "pencil.circle.fill")
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(6)
    }
    .padding(.horizontal, 12)
    .padding(.top, 12)
  }
  
  private var editSelectorView: some View {
    VStack(alignment: .leading, spacing: 8) {
      Toggle("Show all edits", isOn: $showAllEdits)
        .toggleStyle(.switch)
        .font(.caption)
      
      if !showAllEdits {
        ScrollView(.horizontal, showsIndicators: false) {
          HStack(spacing: 8) {
            ForEach(Array(edits.enumerated()), id: \.offset) { index, _ in
              Button(action: { selectedEditIndex = index }) {
                Text("Edit \(index + 1)")
                  .font(.caption)
                  .padding(.horizontal, 12)
                  .padding(.vertical, 6)
                  .background(
                    selectedEditIndex == index
                    ? Color.blue
                    : Color.gray.opacity(0.2)
                  )
                  .foregroundColor(
                    selectedEditIndex == index
                    ? .white
                    : .primary
                  )
                  .cornerRadius(6)
              }
              .buttonStyle(.plain)
            }
          }
        }
      }
    }
    .padding(.horizontal, 12)
  }
  
  @ViewBuilder
  private func editDiffSection(index: Int, oldString: String, newString: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      // Edit header
      HStack {
        Label("Edit \(index + 1)", systemImage: "number.circle.fill")
          .font(.system(size: fontSize - 1, weight: .medium))
          .foregroundStyle(.secondary)
        
        if let replaceAll = edits[index]["replace_all"],
           replaceAll.lowercased() == "true" {
          Text("Replace All")
            .font(.caption2)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.orange.opacity(0.2))
            .foregroundColor(.orange)
            .cornerRadius(4)
        }
        
        Spacer()
      }
      
      // Inline diff for this edit
      VStack(alignment: .leading, spacing: 0) {
        // Create a mini diff view using the same styling as InlineDiffView
        if let diffViewModel = createDiffViewModel(oldString: oldString, newString: newString) {
          if let formattedDiff = diffViewModel.formattedDiff {
            InlineDiffView(formattedDiff: formattedDiff)
              .frame(maxHeight: 200)
              .cornerRadius(4)
              .overlay(
                RoundedRectangle(cornerRadius: 4)
                  .strokeBorder(Color.gray.opacity(0.3), lineWidth: 1)
              )
          }
        } else {
          // Fallback to simple display
          simpleDiffView(oldString: oldString, newString: newString)
        }
      }
    }
    .padding(12)
    .background(Color.gray.opacity(0.05))
    .cornerRadius(8)
  }
  
  @ViewBuilder
  private func simpleDiffView(oldString: String, newString: String) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      // Old content
      HStack(alignment: .top, spacing: 8) {
        Text("-")
          .font(.system(size: fontSize, weight: .medium, design: .monospaced))
          .foregroundColor(.red)
          .frame(width: 20)
        
        Text(oldString)
          .font(.system(size: fontSize - 1, design: .monospaced))
          .foregroundColor(.primary.opacity(0.9))
          .padding(.vertical, 4)
          .padding(.horizontal, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            RoundedRectangle(cornerRadius: 4)
              .fill(Color.red.opacity(0.12))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 4)
              .strokeBorder(Color.red.opacity(0.3), lineWidth: 1)
          )
      }
      
      // New content
      HStack(alignment: .top, spacing: 8) {
        Text("+")
          .font(.system(size: fontSize, weight: .medium, design: .monospaced))
          .foregroundColor(.green)
          .frame(width: 20)
        
        Text(newString)
          .font(.system(size: fontSize - 1, design: .monospaced))
          .foregroundColor(.primary.opacity(0.9))
          .padding(.vertical, 4)
          .padding(.horizontal, 8)
          .frame(maxWidth: .infinity, alignment: .leading)
          .background(
            RoundedRectangle(cornerRadius: 4)
              .fill(Color.green.opacity(0.12))
          )
          .overlay(
            RoundedRectangle(cornerRadius: 4)
              .strokeBorder(Color.green.opacity(0.3), lineWidth: 1)
          )
      }
    }
    .padding(8)
    .background(Color.gray.opacity(0.05))
    .cornerRadius(4)
  }
  
  private func createDiffViewModel(oldString: String, newString: String) -> DiffRenderViewModel? {
    // For now, return nil to use simple view
    // In a real implementation, you'd create the view model
    return nil
  }
}

// MARK: - Preview

#Preview {
  MultiEditToolDiffView(
    edits: [
      ["old_string": "func oldFunction() {", "new_string": "func newFunction() {", "replace_all": "true"],
      ["old_string": "print(\"Hello\")", "new_string": "print(\"Hello, World!\")"],
      ["old_string": "return nil", "new_string": "return value"]
    ],
    filePath: "/path/to/file.swift",
    fontSize: 13,
    contentTextColor: .primary,
    terminalService: MockTerminalService()
  )
  .frame(width: 600, height: 400)
  .padding()
}

// Mock for preview
private struct MockTerminalService: TerminalService {
  func runTerminal(_ command: String, input: String?, quiet: Bool, cwd: String?) async throws -> TerminalResult {
    TerminalResult(exitCode: 0, output: "", errorOutput: nil)
  }
}
