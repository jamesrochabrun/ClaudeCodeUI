import SwiftUI
import CCTerminalServiceInterface

struct EditToolDiffView: View {
  let oldString: String
  let newString: String
  let filePath: String
  let fontSize: Double
  let contentTextColor: Color
  let terminalService: TerminalService
  
  @State private var diffViewModel: DiffRenderViewModel?
  
  var body: some View {
    Group {
      if let viewModel = diffViewModel {
        if viewModel.isLoading {
          loadingView
        } else if let error = viewModel.error {
          errorView(error: error)
        } else if viewModel.formattedDiff != nil {
          UnifiedDiffView(
            formattedDiff: viewModel.formattedDiff,
            fileName: URL(fileURLWithPath: filePath).lastPathComponent
          )
          .padding(8)
        } else {
          fallbackView
        }
      } else {
        ProgressView()
          .frame(maxWidth: .infinity, minHeight: 100)
          .onAppear {
            createDiffViewModel()
          }
      }
    }
  }
  
  private var loadingView: some View {
    VStack {
      ProgressView()
      Text("Generating diff...")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 100)
  }
  
  private func errorView(error: String) -> some View {
    VStack {
      Image(systemName: "exclamationmark.triangle")
        .foregroundStyle(.red)
      Text("Error generating diff: \(error)")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .padding()
    .frame(maxWidth: .infinity)
  }
  
  private var fallbackView: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("File: \(URL(fileURLWithPath: filePath).lastPathComponent)")
        .font(.caption)
        .foregroundStyle(.secondary)
      Text("Changes to be applied:")
        .font(.caption.bold())
      Text("Old: \(oldString)")
        .font(.system(size: fontSize - 1, design: .monospaced))
        .foregroundColor(contentTextColor)
      Text("New: \(newString)")
        .font(.system(size: fontSize - 1, design: .monospaced))
        .foregroundColor(contentTextColor)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .leading)
  }
  
  private func createDiffViewModel() {
    diffViewModel = DiffRenderViewModel(
      oldContent: oldString,
      newContent: newString,
      terminalService: terminalService
    )
  }
}