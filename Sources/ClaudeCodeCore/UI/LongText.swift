import AppKit
import SwiftUI

/// A performant text view optimized for displaying long content with attributed text support.
///
/// `LongText` provides an efficient way to display large amounts of text that would
/// otherwise cause performance issues with SwiftUI's standard `Text` view. It uses
/// NSTextView under the hood for optimal performance with text selection support.
///
/// ## Features
/// - Efficient rendering of long text content
/// - Support for NSAttributedString and AttributedString
/// - Text selection capability
/// - Automatic color scheme adaptation
/// - Configurable maximum width for text wrapping
///
/// ## Usage Examples
/// ```swift
/// // With AttributedString
/// LongText(attributedString, maxWidth: 600)
///
/// // With plain string
/// LongText("Long text content...", font: .systemFont(ofSize: 14))
///
/// // With NSAttributedString
/// LongText(nsAttributedString)
/// ```
public struct LongText: View {
  
  // MARK: - Initializers
  
  /// Creates a LongText view with an NSAttributedString
  /// - Parameters:
  ///   - text: The attributed string to display
  ///   - maxWidth: Maximum width for text wrapping (defaults to no limit)
  public init(_ text: NSAttributedString, maxWidth: CGFloat = .greatestFiniteMagnitude) {
    self.init(text, needColoring: false, maxWidth: maxWidth)
  }
  
  /// Private initializer that handles the core setup
  /// - Parameters:
  ///   - text: The attributed string to display
  ///   - needColoring: Whether to apply color scheme-based coloring
  ///   - maxWidth: Maximum width for text wrapping
  private init(_ text: NSAttributedString, needColoring: Bool, maxWidth: CGFloat) {
    self.text = text
    self.needColoring = needColoring
    self.maxWidth = maxWidth
  }
  
  /// Creates a LongText view with a SwiftUI AttributedString
  /// - Parameters:
  ///   - text: The SwiftUI attributed string to display
  ///   - maxWidth: Maximum width for text wrapping (defaults to no limit)
  public init(_ text: AttributedString, maxWidth: CGFloat = .greatestFiniteMagnitude) {
    self.init(NSAttributedString(text), needColoring: false, maxWidth: maxWidth)
  }
  
  /// Creates a LongText view with a plain string and font
  /// - Parameters:
  ///   - text: The plain text to display
  ///   - font: The font to apply to the text
  ///   - maxWidth: Maximum width for text wrapping (defaults to no limit)
  public init(_ text: String, font: NSFont = .systemFont(ofSize: 14), maxWidth: CGFloat = .greatestFiniteMagnitude) {
    let attrString = NSMutableAttributedString(attributedString: NSAttributedString(string: text))
    let range = NSRange(location: 0, length: attrString.length)
    attrString.addAttribute(.font, value: font, range: range)
    
    self.init(attrString, needColoring: true, maxWidth: maxWidth)
  }
  
  // MARK: - View Body
  
  public var body: some View {
    InnerLongText(attributedTextWithFont, maxWidth: maxWidth)
  }
  
  // MARK: - Properties
  
  /// The attributed string to display
  let text: NSAttributedString
  
  /// Whether to apply automatic color scheme-based coloring
  let needColoring: Bool
  
  /// Maximum width for text wrapping
  let maxWidth: CGFloat
  
  // MARK: - Static Methods
  
  /// Calculates the size needed to display the given attributed string
  /// - Parameters:
  ///   - text: The attributed string to measure
  ///   - maxWidth: The maximum width constraint
  /// - Returns: The calculated size needed to display the text
  static func size(for text: NSAttributedString, maxWidth: CGFloat) -> CGSize {
    let layoutManager = NSLayoutManager()
    let textContainer = NSTextContainer(size: .zero)
    let textStorage = NSTextStorage()
    
    textStorage.addLayoutManager(layoutManager)
    layoutManager.addTextContainer(textContainer)
    
    textStorage.setAttributedString(text)
    textContainer.containerSize = NSSize(width: maxWidth, height: .greatestFiniteMagnitude)
    layoutManager.glyphRange(for: textContainer)
    let usedRect = layoutManager.usedRect(for: textContainer)
    return usedRect.integral.size
  }
  
  // MARK: - Environment Properties
  
  @Environment(\.colorScheme) private var colorScheme: ColorScheme
  @Environment(\.font) private var environmentFont
  
  // MARK: - Computed Properties
  
  /// Attempts to convert SwiftUI Font to NSFont
  /// Currently returns a default system font when environment font is set
  private var nsEnvironmentFont: NSFont? {
    // Convert SwiftUI Font to NSFont if needed
    // For now, we'll use the system font
    if environmentFont != nil {
      return .systemFont(ofSize: 14)
    }
    return nil
  }
  
  /// Returns the text with appropriate font and color attributes applied
  /// based on the current color scheme and environment settings
  private var attributedTextWithFont: NSAttributedString {
    if text.length == 0 {
      return text
    }
    guard nsEnvironmentFont != nil || needColoring else {
      return text
    }
    
    let mutableText = NSMutableAttributedString(attributedString: text)
    let range = NSRange(location: 0, length: mutableText.length)
    
    if needColoring {
      let color = colorScheme == .dark ? NSColor.white : NSColor.black
      if text.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor != color {
        mutableText.addAttribute(.foregroundColor, value: color, range: range)
      }
    }
    
    if let fontToUse = nsEnvironmentFont,
       text.attribute(.font, at: 0, effectiveRange: nil) as? NSFont != fontToUse {
      mutableText.addAttribute(.font, value: fontToUse, range: range)
    }
    
    return mutableText
  }
}

// MARK: - InnerLongText

/// A wrapper view that manages the sizing and layout of the long text content
public struct InnerLongText: View {
  
  /// Creates an InnerLongText view with calculated size
  /// - Parameters:
  ///   - text: The attributed string to display
  ///   - maxWidth: Maximum width constraint
  public init(_ text: NSAttributedString, maxWidth: CGFloat) {
    self.text = text
    self.maxWidth = maxWidth
    textSize = LongText.size(for: text, maxWidth: maxWidth)
  }
  
  public var body: some View {
    NSLongText(attributedString: text, maxWidth: maxWidth)
      .frame(width: textSize.width, height: textSize.height)
  }
  
  /// The attributed string to display
  let text: NSAttributedString
  
  /// Maximum width constraint
  let maxWidth: CGFloat
  
  /// Pre-calculated size for the text
  private let textSize: CGSize
}

// MARK: - NSLongText

/// NSViewRepresentable wrapper for NSTextView to provide efficient text rendering
struct NSLongText: NSViewRepresentable {
  /// The attributed string to display in the text view
  let attributedString: NSAttributedString
  
  /// Maximum width constraint for the text view
  let maxWidth: CGFloat
  
  /// Creates and configures an NSTextView for displaying the text
  /// - Parameter context: The context for creating the view
  /// - Returns: A configured NSTextView instance
  func makeNSView(context _: Context) -> NSTextView {
    // Set up the text system components
    let textStorage = NSTextStorage(attributedString: attributedString)
    let layoutManager = NSLayoutManager()
    let textContainer = NSTextContainer()
    
    textStorage.addLayoutManager(layoutManager)
    layoutManager.addTextContainer(textContainer)
    
    // Create and configure the text view
    let textView = NSTextView(frame: .zero, textContainer: textContainer)
    
    // Configure text view properties
    textView.isEditable = false                    // Read-only
    textView.isSelectable = true                   // Allow text selection
    textView.isVerticallyResizable = false         // Fixed height
    textView.isHorizontallyResizable = false       // Fixed width
    textView.textContainer?.size = LongText.size(for: attributedString, maxWidth: maxWidth)
    textView.textContainer?.widthTracksTextView = false
    textView.backgroundColor = .clear              // Transparent background
    return textView
  }
  
  /// Updates the text view when the content changes
  /// - Parameters:
  ///   - nsView: The NSTextView to update
  ///   - context: The update context
  func updateNSView(_ nsView: NSTextView, context _: Context) {
    nsView.textStorage?.setAttributedString(attributedString)
    nsView.textContainer?.size = LongText.size(for: attributedString, maxWidth: maxWidth)
    nsView.needsLayout = true
    nsView.needsDisplay = true
  }
}

