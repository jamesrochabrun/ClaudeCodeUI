import SwiftUI

struct DiffColors {
  static func backgroundColorForAddedLines(in colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(hex: "#29EC39").opacity(0.1) : Color.green.opacity(0.1)
  }
  
  static func backgroundColorForRemovedLines(in colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(hex: "#FF3E41").opacity(0.1) : Color.red.opacity(0.1)
  }
  
  static func backgroundColorForCodeBlockHeader(in colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color(white: 0.15) : Color(white: 0.95)
  }
  
  static func borderColorForCodeBlocks(in colorScheme: ColorScheme) -> Color {
    colorScheme == .dark ? Color.gray.opacity(0.3) : Color.gray.opacity(0.2)
  }
}
