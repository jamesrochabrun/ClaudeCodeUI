import SwiftUI
import AppKit
import Down

class MarkdownStyle: DownStyle {
  
  init(colorScheme: ColorScheme) {
    super.init()
    
    baseFont = NSFont.systemFont(ofSize: 14, weight: .regular)
    baseFontColor = colorScheme.primaryForeground.nsColor
    
    let paragraphStyle = NSMutableParagraphStyle()
    paragraphStyle.paragraphSpacingBefore = 0
    paragraphStyle.paragraphSpacing = 0
    paragraphStyle.lineSpacing = 3
    baseParagraphStyle = paragraphStyle
    
    h1Size = 18
    h2Size = 16
    h3Size = 15
    codeFont = .monospacedSystemFont(ofSize: 13, weight: .regular)
    // Use bookCloth color for inline code (like branch names)
    codeColor = SwiftUI.Color.bookCloth.nsColor
    quoteColor = .secondaryLabelColor
    
    // Configure link color to match the theme
    //        linkColor = SwiftUI.Color.bookCloth.nsColor
    
    // You can also set these if needed:
    // listItemColor = baseFontColor
    // strikethroughColor = .secondaryLabelColor
  }
  
  override var h1Attributes: DownStyle.Attributes {
    super.h1Attributes.merging([
      .font: baseFont.withSize(h1Size),
    ])
  }
  
  override var h2Attributes: DownStyle.Attributes {
    super.h2Attributes.merging([
      .font: baseFont.withSize(h2Size),
    ])
  }
  
  override var h3Attributes: DownStyle.Attributes {
    super.h3Attributes.merging([
      .font: baseFont.withSize(h3Size),
    ])
  }
}

extension DownStyle.Attributes {
  func merging(_ other: DownStyle.Attributes) -> DownStyle.Attributes {
    merging(other, uniquingKeysWith: { $1 })
  }
}

// Extension to add NSFont size adjustment
extension NSFont {
  func withSize(_ size: CGFloat) -> NSFont {
    return NSFont(descriptor: fontDescriptor, size: size) ?? self
  }
}

// Extension to convert SwiftUI Color to NSColor
extension SwiftUI.Color {
  var nsColor: NSColor {
    return NSColor(self)
  }
}

// Add theme colors to ColorScheme
extension ColorScheme {
  var primaryForeground: SwiftUI.Color {
    self == .dark ? .white : .black
  }
}
