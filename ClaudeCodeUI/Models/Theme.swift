//import SwiftUI
//
//struct Theme: Identifiable, Codable, Equatable {
//  let id: String
//  let name: String
//  let colors: ThemeColors
//  
//  struct ThemeColors: Codable, Equatable {
//    // Primary colors
//    let primary: String
//    let secondary: String
//    let tertiary: String
//    
//    // Background colors
//    let background: String
//    let secondaryBackground: String
//    let tertiaryBackground: String
//    
//    // Content colors
//    let primaryText: String
//    let secondaryText: String
//    let tertiaryText: String
//    
//    // Accent colors
//    let accent: String
//    let accentSecondary: String
//    
//    // Semantic colors
//    let success: String
//    let warning: String
//    let error: String
//    let info: String
//    
//    // UI element colors
//    let border: String
//    let divider: String
//    let shadow: String
//    
//    // Special purpose colors
//    let codeBackground: String
//    let codeText: String
//    let link: String
//    let selection: String
//  }
//}
//
//extension Theme {
//  // Anthropic theme using the provided color palette
//  static let anthropic = Theme(
//    id: "anthropic",
//    name: "Anthropic",
//    colors: ThemeColors(
//      primary: "#CC785C",           // bookCloth
//      secondary: "#D4A27F",         // kraft
//      tertiary: "#EBDBBC",          // manilla
//      background: "#FAF9F5",        // backgroundLight
//      secondaryBackground: "#F8F4E3", // expandedContentBackgroundLight
//      tertiaryBackground: "#FFFFFF",
//      primaryText: "#262624",       // backgroundDark (used for text)
//      secondaryText: "#4A4A48",
//      tertiaryText: "#6B6B68",
//      accent: "#CC785C",            // bookCloth
//      accentSecondary: "#D4A27F",   // kraft
//      success: "#4CAF50",
//      warning: "#FF9800",
//      error: "#F44336",
//      info: "#2196F3",
//      border: "#E0E0E0",
//      divider: "#EEEEEE",
//      shadow: "#00000010",
//      codeBackground: "#F5F5F5",
//      codeText: "#333333",
//      link: "#CC785C",
//      selection: "#CC785C30"
//    )
//  )
//  
//  // Anthropic Dark theme
//  static let anthropicDark = Theme(
//    id: "anthropic-dark",
//    name: "Anthropic Dark",
//    colors: ThemeColors(
//      primary: "#CC785C",           // bookCloth
//      secondary: "#D4A27F",         // kraft
//      tertiary: "#EBDBBC",          // manilla
//      background: "#262624",        // backgroundDark
//      secondaryBackground: "#222222", // expandedContentBackgroundDark
//      tertiaryBackground: "#1A1A1A",
//      primaryText: "#FAF9F5",       // backgroundLight (used for text)
//      secondaryText: "#B5B5B0",
//      tertiaryText: "#949490",
//      accent: "#CC785C",            // bookCloth
//      accentSecondary: "#D4A27F",   // kraft
//      success: "#66BB6A",
//      warning: "#FFA726",
//      error: "#EF5350",
//      info: "#42A5F5",
//      border: "#3A3A38",
//      divider: "#2E2E2C",
//      shadow: "#00000040",
//      codeBackground: "#1E1E1C",
//      codeText: "#E0E0E0",
//      link: "#D4A27F",
//      selection: "#CC785C50"
//    )
//  )
//  
//  // Default purple theme (based on existing theme)
//  static let defaultPurple = Theme(
//    id: "default-purple",
//    name: "Default Purple",
//    colors: ThemeColors(
//      primary: "#8B5CF6",
//      secondary: "#A78BFA",
//      tertiary: "#C4B5FD",
//      background: "#FFFFFF",
//      secondaryBackground: "#F9FAFB",
//      tertiaryBackground: "#F3F4F6",
//      primaryText: "#111827",
//      secondaryText: "#6B7280",
//      tertiaryText: "#9CA3AF",
//      accent: "#8B5CF6",
//      accentSecondary: "#A78BFA",
//      success: "#10B981",
//      warning: "#F59E0B",
//      error: "#EF4444",
//      info: "#3B82F6",
//      border: "#E5E7EB",
//      divider: "#F3F4F6",
//      shadow: "#00000010",
//      codeBackground: "#F3F4F6",
//      codeText: "#374151",
//      link: "#8B5CF6",
//      selection: "#8B5CF630"
//    )
//  )
//  
//  // XCode theme
//  static let xcode = Theme(
//    id: "xcode",
//    name: "Xcode",
//    colors: ThemeColors(
//      primary: "#007AFF",
//      secondary: "#5AC8FA",
//      tertiary: "#46D7FF",
//      background: "#FFFFFF",
//      secondaryBackground: "#F5F5F7",
//      tertiaryBackground: "#EFEFF4",
//      primaryText: "#000000",
//      secondaryText: "#3C3C43",
//      tertiaryText: "#8E8E93",
//      accent: "#007AFF",
//      accentSecondary: "#5AC8FA",
//      success: "#34C759",
//      warning: "#FF9500",
//      error: "#FF3B30",
//      info: "#5856D6",
//      border: "#C6C6C8",
//      divider: "#D1D1D6",
//      shadow: "#00000010",
//      codeBackground: "#F5F5F7",
//      codeText: "#000000",
//      link: "#007AFF",
//      selection: "#007AFF30"
//    )
//  )
//  
//  // All available themes
//  static let allThemes: [Theme] = [
//    .anthropic,
//    .anthropicDark,
//    .defaultPurple,
//    .xcode
//  ]
//  
//  // Get theme by ID
//  static func theme(withId id: String) -> Theme? {
//    allThemes.first { $0.id == id }
//  }
//}
//
//// Color extension to work with hex strings
//extension Color {
//  init(hex: String) {
//    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
//    var int: UInt64 = 0
//    Scanner(string: hex).scanHexInt64(&int)
//    let a, r, g, b: UInt64
//    switch hex.count {
//    case 3: // RGB (12-bit)
//      (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
//    case 6: // RGB (24-bit)
//      (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
//    case 8: // ARGB (32-bit)
//      (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
//    default:
//      (a, r, g, b) = (255, 0, 0, 0)
//    }
//    self.init(
//      .sRGB,
//      red: Double(r) / 255,
//      green: Double(g) / 255,
//      blue: Double(b) / 255,
//      opacity: Double(a) / 255
//    )
//  }
//}
