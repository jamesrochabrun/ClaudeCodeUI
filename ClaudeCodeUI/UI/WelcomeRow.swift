//
//  WelcomeRow.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 6/21/25.
//

import Foundation
import SwiftUI

struct WelcomeRow: View {
  let path: String
  
  // Custom color
  init(path: String) {
    self.path = path
  }
  
  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text("✻")
        .foregroundColor(.bookCloth)
      VStack(alignment: .leading, spacing: 16) {
        Text("Welcome to **Claude Code UI!**")
          .font(.system(.body, design: .monospaced))
          .foregroundColor(.primary)
        Text(path)
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.secondary)
      }
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(12)
    .overlay(
      RoundedRectangle(cornerRadius: 4)
        .stroke(Color.bookCloth, lineWidth: 1)
    )
    .padding(12)
  }
}

#Preview {
  WelcomeRow(path: "cwd: /Users/jamesrochabrun/Desktop/git/ClaudeCodeUI")
}
