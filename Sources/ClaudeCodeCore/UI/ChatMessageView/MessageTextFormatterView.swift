import SwiftUI
import Down
import AppKit

struct MessageTextFormatterView: View {
  let textFormatter: TextFormatter
  let message: ChatMessage
  let fontSize: Double
  let horizontalPadding: CGFloat
  let maxWidth: CGFloat
  let showArtifact: ((Artifact) -> Void)?
  
  @Environment(\.colorScheme) private var colorScheme
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(textFormatter.elements) { element in
        textElementView(element)
      }
      
      // Show loading indicator if still streaming
      if !message.isComplete && textFormatter.elements.isEmpty {
        MessageLoadingIndicator(messageTint: messageTint)
      }
      
      // Show cancelled indicator if message was cancelled
      if message.wasCancelled {
        HStack {
          Text("Interrupted by user")
            .font(.system(size: fontSize - 1))
            .foregroundColor(.red)
            .padding(.horizontal, horizontalPadding)
            .padding(.vertical, 8)
        }
      }
    }
  }
  
  @ViewBuilder
  private func textElementView(_ element: TextFormatter.Element) -> some View {
    switch element {
    case .text(let text):
      let attributedText = message.role == .user ? plainText(for: text) : markdown(for: text)
      LongText(attributedText, maxWidth: maxWidth - 2 * horizontalPadding)
        .textSelection(.enabled)
        .padding(.horizontal, horizontalPadding)
        .padding(.vertical, 8)
      
    case .codeBlock(let code):
      CodeBlockContentView(code: code, role: message.role, showArtifact: showArtifact)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
      
    case .table(let table):
      TableContentView(table: table, role: message.role)
        .padding(.horizontal, 4)
        .padding(.vertical, 4)
    }
  }
  
  private func markdown(for text: TextFormatter.Element.TextElement) -> AttributedString {
    let markDown = Down(markdownString: text.text)
    do {
      let attributedString = try markDown.toAttributedString(using: style)
      return AttributedString(attributedString.trimmedAttributedString())
    } catch {
      print("Error parsing markdown: \(error)")
      return AttributedString(text.text)
    }
  }
  
  private func plainText(for text: TextFormatter.Element.TextElement) -> AttributedString {
    var attrs = AttributedString(text.text)
    attrs.foregroundColor = SwiftUI.Color(style.baseFontColor)
    attrs.font = Font(style.baseFont as CTFont)
    return attrs
  }
  
  private var style: MarkdownStyle {
    MarkdownStyle(colorScheme: colorScheme)
  }
  
  private var messageTint: SwiftUI.Color {
    switch message.messageType {
    case .text:
      return message.role == .assistant ? SwiftUI.Color(red: 147/255, green: 51/255, blue: 234/255) : .primary
    case .toolUse:
      return SwiftUI.Color(red: 255/255, green: 149/255, blue: 0/255)
    case .toolResult:
      return SwiftUI.Color(red: 52/255, green: 199/255, blue: 89/255)
    case .toolError:
      return SwiftUI.Color(red: 255/255, green: 59/255, blue: 48/255)
    case .toolDenied:
      return SwiftUI.Color.secondary
    case .thinking:
      return SwiftUI.Color(red: 90/255, green: 200/255, blue: 250/255)
    case .webSearch:
      return SwiftUI.Color(red: 0/255, green: 199/255, blue: 190/255)
    }
  }
}

struct MessageLoadingIndicator: View {
  let messageTint: SwiftUI.Color
  @State private var animationValues: [Bool] = [false, false, false]
  
  var body: some View {
    HStack(spacing: 8) {
      ForEach(0..<3) { index in
        Circle()
          .fill(
            LinearGradient(
              colors: [messageTint, messageTint.opacity(0.6)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: 8, height: 8)
          .scaleEffect(animationValues[index] ? 1.2 : 0.8)
          .animation(
            Animation.easeInOut(duration: 0.6)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.15),
            value: animationValues[index]
          )
          .onAppear {
            animationValues[index].toggle()
          }
      }
    }
    .padding(.vertical, 4)
  }
}

/// Extension to provide whitespace trimming functionality for NSAttributedString
extension NSAttributedString {
  /// Removes leading and trailing whitespace and newline characters from an attributed string
  /// while preserving all text attributes.
  ///
  /// - Returns: A new NSAttributedString with whitespace trimmed from both ends.
  ///            Returns an empty attributed string if the original contains only whitespace.
  ///
  /// - Note: This method preserves all attributes of the non-whitespace content.
  ///
  /// Example:
  /// ```swift
  /// let attributed = NSAttributedString(string: "  Hello World  ")
  /// let trimmed = attributed.trimmedAttributedString()
  /// // Result: "Hello World" with original attributes preserved
  /// ```
  public func trimmedAttributedString() -> NSAttributedString {
    // Create character set for non-whitespace characters
    let nonWhiteSpace = CharacterSet.whitespacesAndNewlines.inverted
    
    // Find the first non-whitespace character from the start
    let startRange = string.rangeOfCharacter(from: nonWhiteSpace)
    
    // Find the first non-whitespace character from the end
    let endRange = string.rangeOfCharacter(from: nonWhiteSpace, options: .backwards)
    
    // If no non-whitespace characters found, return empty attributed string
    guard let startLocation = startRange?.lowerBound, let endLocation = endRange?.lowerBound else {
      return NSAttributedString(string: "")
    }
    
    // If the string doesn't need trimming, return self
    if startLocation == string.startIndex, endLocation == string.index(before: string.endIndex) {
      return self
    }
    
    // Create range from first to last non-whitespace character (inclusive)
    let trimmedRange = startLocation...endLocation
    
    // Extract and return the substring with preserved attributes
    return attributedSubstring(from: NSRange(trimmedRange, in: string))
  }
}