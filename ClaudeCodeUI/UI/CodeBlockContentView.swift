import SwiftUI
import AppKit

struct CodeBlockContentView: View {
  
  @Bindable var code: CodeBlockElement
  let role: MessageRole
  let showArtifact: ((Artifact) -> Void)?
  let iconSizes: CGFloat = 15
  
  @Environment(\.colorScheme) private var colorScheme
  
  init(code: CodeBlockElement, role: MessageRole, showArtifact: ((Artifact) -> Void)? = nil) {
    self.code = code
    self.role = role
    self.showArtifact = showArtifact
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        // File icon and path
        if let filePath = code.filePath {
          Image(systemName: fileIcon(for: filePath))
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
          
          Text(URL(fileURLWithPath: filePath).lastPathComponent)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.secondary)
        } else if let language = code.language {
          Text(language)
            .font(.system(size: 12, design: .monospaced))
            .foregroundStyle(.secondary)
        }
        
        Spacer()
        
        // View Diagram button for mermaid
        if let showArtifact = showArtifact,
           let language = code.language,
           language.lowercased() == "mermaid",
           let content = code.copyableContent {
          Button(action: {
            showArtifact(.diagram(content))
          }) {
            HStack(spacing: 4) {
              Image(systemName: "flowchart")
                .font(.system(size: 12))
              Text("View")
                .font(.system(size: 12))
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.1))
            .foregroundColor(.blue)
            .cornerRadius(4)
          }
          .buttonStyle(.plain)
          .help("View Mermaid Diagram")
        }
        
        // Copy button
        if let copyableContent = code.copyableContent {
          Button(action: {
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(copyableContent, forType: .string)
          }) {
            Image(systemName: "doc.on.doc")
              .font(.system(size: iconSizes))
          }
          .buttonStyle(.plain)
          .help("Copy code")
        }
        
        // Loading indicator for incomplete code blocks
        if !code.isComplete {
          ProgressView()
            .controlSize(.small)
            .frame(width: iconSizes, height: iconSizes)
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(headerBackground)
      
      Divider()
      
      // Code content
      ScrollView(.vertical) {
        ScrollView(.horizontal, showsIndicators: false) {
          if let highlightedText = code.highlightedText {
            // Use highlighted text when available
            Text(highlightedText)
              .font(.system(size: 13, design: .monospaced))
              .textSelection(.enabled)
              .padding(12)
          } else {
            // Fallback to plain text
            Text(code.content)
              .font(.system(size: 13, design: .monospaced))
              .foregroundColor(codeTextColor)
              .textSelection(.enabled)
              .padding(12)
          }
        }
      }
      .frame(maxHeight: 500)
      .background(codeBackground)
    }
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .strokeBorder(borderColor, lineWidth: 1)
    )
  }
  
  private var headerBackground: Color {
    colorScheme == .dark
    ? Color(white: 0.15)
    : Color(white: 0.95)
  }
  
  private var codeBackground: Color {
    colorScheme == .dark
    ? Color(white: 0.1)
    : Color(white: 0.98)
  }
  
  private var borderColor: Color {
    colorScheme == .dark
    ? Color(white: 0.25)
    : Color(white: 0.85)
  }
  
  private var codeTextColor: Color {
    colorScheme == .dark
    ? Color.white.opacity(0.9)
    : Color.black.opacity(0.85)
  }
  
  private func fileIcon(for path: String) -> String {
    let ext = URL(fileURLWithPath: path).pathExtension.lowercased()
    
    switch ext {
    case "swift":
      return "swift"
    case "js", "jsx", "ts", "tsx":
      return "curlybraces"
    case "py":
      return "chevron.left.forwardslash.chevron.right"
    case "json", "xml", "yml", "yaml":
      return "doc.text"
    case "md", "markdown":
      return "text.alignleft"
    case "sh", "bash":
      return "terminal"
    default:
      return "doc"
    }
  }
  
}
