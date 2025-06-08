//
//  Color+Extension.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 6/8/25.
//

import Foundation
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
}
