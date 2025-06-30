import Combine
import Foundation
import Observation
import HighlightSwift

/// A view model that represents a code block element within a chat message.
/// 
/// This class manages the parsing, syntax highlighting, and display of code blocks
/// that appear in assistant responses. It handles both streaming (incomplete) and
/// completed code blocks, applying syntax highlighting using the HighlightSwift library.
///
/// ## Features
/// - Automatic syntax highlighting based on language detection
/// - Support for streaming content updates
/// - File path resolution relative to project root
/// - Copyable content generation
/// - Future support for file diff operations
///
/// ## Usage
/// ```swift
/// let codeBlock = CodeBlockElement(
///     projectRoot: URL(fileURLWithPath: "/path/to/project"),
///     rawContent: "```swift\nprint(\"Hello\")\n```",
///     isComplete: true,
///     id: 1
/// )
/// ```
@MainActor
@Observable
class CodeBlockElement {
  
  /// Initializes a new code block element.
  /// 
  /// - Parameters:
  ///   - projectRoot: The root directory of the project for resolving relative file paths
  ///   - rawContent: The raw content of the code block (may include language identifier)
  ///   - isComplete: Whether the code block has finished streaming
  ///   - id: A unique identifier for this code block
  init(projectRoot: URL?, rawContent: String, isComplete: Bool, id: Int) {
    self.projectRoot = projectRoot
    self.id = id
    let content = rawContent.trimmed(isComplete: isComplete)
    _content = content
    _rawContent = content
    self.isComplete = isComplete
    
    Task {
      await applySyntaxHighlighting()
    }
    
    handleIsCompletedChanged()
  }
  
  // MARK: - Public Properties
  
  /// The unique identifier for this code block
  let id: Int
  
  /// The programming language of the code block (e.g., "swift", "python")
  /// Automatically detected from the code fence in markdown
  var language: String?
  
  /// The processed content of the code block without language identifier or extra whitespace
  private(set) var content: String
  
  /// The syntax-highlighted version of the content as an AttributedString
  /// This is generated asynchronously after initialization or content updates
  private(set) var highlightedText: AttributedString?
  
  /// Whether the code block has finished streaming from the assistant
  private(set) var isComplete: Bool
  
  /// The content formatted for copying to clipboard
  /// This is typically the same as `content` but may differ for special cases
  private(set) var copyableContent: String?
  
  /// View model for handling file diff operations (future feature)
  var fileChange: FileDiffViewModel?
  
  /// The file path associated with this code block, if any
  /// When set, relative paths are automatically resolved to absolute paths
  var filePath: String? {
    didSet {
      // Resolve to absolute path
      if let filePath {
        let resolvedPath = filePath.resolvePath(from: projectRoot).path()
        if resolvedPath != filePath {
          self.filePath = resolvedPath
        }
      }
    }
  }
  
  // MARK: - Private Properties
  
  /// The raw content as received from the stream, before processing
  private(set) var rawContent: String {
    didSet {
      content = rawContent
    }
  }
  
  /// The project root directory for resolving relative paths
  private let projectRoot: URL?
  
  /// Combine cancellables for managing subscriptions
  private var cancellables = Set<AnyCancellable>()
  
  // MARK: - Public Methods
  
  /// Updates the code block with new content, typically during streaming
  /// 
  /// - Parameters:
  ///   - rawContent: The new raw content
  ///   - isComplete: Whether streaming has completed
  func set(rawContent: String, isComplete: Bool) {
    self.isComplete = isComplete
    self.rawContent = rawContent.trimmed(isComplete: isComplete)
    
    // Apply syntax highlighting
    Task {
      await applySyntaxHighlighting()
    }
    
    handleIsCompletedChanged()
  }
  
  // MARK: - Private Methods
  
  /// Handles updates when the code block completion status changes
  /// Sets up copyable content and prepares for potential file diff operations
  @MainActor
  private func handleIsCompletedChanged() {
    guard isComplete else { return }
    
    if filePath == nil {
      // Not a diff/new file
      copyableContent = rawContent
      return
    }
    
    // For now, we'll handle file diffs later
    // Just set the content as copyable
    copyableContent = rawContent
  }
  
  /// Applies syntax highlighting to the code content asynchronously
  /// Uses HighlightSwift to generate an AttributedString with appropriate colors
  @MainActor
  private func applySyntaxHighlighting() async {
    guard let language = language else {
      copyableContent = content
      return
    }
    
    do {
      let highlighter = Highlight()
      
      // Map our language to highlight.js language names
      let highlightLanguage = mapToHighlightLanguage(language)
      
      let highlighted = try await highlighter.attributedText(content, language: highlightLanguage)
      highlightedText = highlighted
      copyableContent = content
    } catch {
      print("Syntax highlighting error: \(error)")
      copyableContent = content
    }
  }
  
  /// Maps common language identifiers to highlight.js language names
  /// 
  /// - Parameter language: The language identifier from the code fence
  /// - Returns: The corresponding highlight.js language name
  private func mapToHighlightLanguage(_ language: String) -> String {
    // Map common language names to highlight.js names
    switch language.lowercased() {
    case "js", "javascript": return "javascript"
    case "ts", "typescript": return "typescript"
    case "swift": return "swift"
    case "python", "py": return "python"
    case "ruby", "rb": return "ruby"
    case "java": return "java"
    case "kotlin", "kt": return "kotlin"
    case "go": return "go"
    case "rust", "rs": return "rust"
    case "cpp", "c++": return "cpp"
    case "c": return "c"
    case "objc", "objective-c": return "objectivec"
    case "cs", "csharp": return "csharp"
    case "php": return "php"
    case "bash", "sh": return "bash"
    case "json": return "json"
    case "xml": return "xml"
    case "yaml", "yml": return "yaml"
    case "markdown", "md": return "markdown"
    case "html": return "html"
    case "css": return "css"
    case "sql": return "sql"
    default: return language
    }
  }
}

// MARK: - String Extension

/// Extension to handle file path resolution
extension String {
  /// Resolves a file path to an absolute URL
  /// 
  /// - Parameter projectRoot: The project root directory for resolving relative paths
  /// - Returns: An absolute file URL
  /// 
  /// ## Behavior:
  /// - If the path starts with "/", it's treated as absolute
  /// - If a project root is provided, relative paths are resolved against it
  /// - Otherwise, the path is converted to a file URL as-is
  func resolvePath(from projectRoot: URL?) -> URL {
    if self.hasPrefix("/") {
      return URL(fileURLWithPath: self)
    } else if let projectRoot = projectRoot {
      return projectRoot.appendingPathComponent(self)
    } else {
      return URL(fileURLWithPath: self)
    }
  }
}

// MARK: - FileDiffViewModel

/// Placeholder for future file diff functionality
/// Will handle applying code changes to files when implemented
class FileDiffViewModel {
  // We'll implement this later when we have all dependencies
}
