//  Color+Extension.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 6/8/25.

import SwiftUI

extension Color {
  /// Create a Color from 0...255 RGB values (and optional alpha)
  init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
    self.init(.sRGB,
              red: red / 255.0,
              green: green / 255.0,
              blue: blue / 255.0,
              opacity: alpha)
  }

  init(red: Int, green: Int, blue: Int, alpha: Double = 1.0) {
    self.init(red: Double(red), green: Double(green), blue: Double(blue), alpha: alpha)
  }

  /// Create a Color from a hex string like "#CC785C" or "CC785C"
  init(hex: String, alpha: Double = 1.0) {
    let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
    var int = UInt64()
    Scanner(string: hex).scanHexInt64(&int)

    let r, g, b: UInt64
    switch hex.count {
    case 6: // RGB (24-bit)
      (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
    default:
      (r, g, b) = (0, 0, 0)
    }

    self.init(red: Int(r), green: Int(g), blue: Int(b), alpha: alpha)
  }

  // MARK: - Named Colors

  static let bookCloth = Color(hex: "#CC785C")
  static let kraft = Color(hex: "#D4A27F")
  static let manilla = Color(hex: "#EBDBBC")
  static let backgroundDark = Color(hex: "##262624")
  static let backgroundLight = Color(hex: "##FAF9F5")
  static let expandedContentBackgroundDark = Color(hex: "#222222")
  static let expandedContentBackgroundLight = Color(hex: "#F8F4E3")

}
