//
//  WelcomeRow.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 6/21/25.
//

import Foundation
import SwiftUI

struct WelcomeRow: View {
  let path: String?
  let showSettingsButton: Bool
  let onSettingsTapped: () -> Void
  
  // Custom color
  init(path: String?, showSettingsButton: Bool = false, onSettingsTapped: @escaping () -> Void = {}) {
    self.path = path
    self.showSettingsButton = showSettingsButton
    self.onSettingsTapped = onSettingsTapped
  }
  
  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text("✻")
        .foregroundColor(.bookCloth)
      VStack(alignment: .leading, spacing: 16) {
        Text("Welcome to **Claude Code UI!**")
          .font(.system(.body, design: .monospaced))
          .foregroundColor(.primary)
        
        if showSettingsButton {
          Button(action: onSettingsTapped) {
            Image(systemName: "plus.circle.fill")
              .font(.system(size: 16))
              .foregroundColor(.bookCloth)
          }
          .buttonStyle(.plain)
          .help("Select Working Directory")
        } else if let path = path {
          HStack(spacing: 8) {
            Text(path)
              .font(.system(.caption, design: .monospaced))
              .foregroundColor(.secondary)
            
            Button(action: onSettingsTapped) {
              Image(systemName: "pencil.circle")
                .font(.caption)
            }
            .buttonStyle(.plain)
            .foregroundColor(.secondary)
            .help("Change working directory")
          }
        }
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
  VStack {
    WelcomeRow(path: "cwd: /Users/jamesrochabrun/Desktop/git/ClaudeCodeUI")
    WelcomeRow(path: nil, showSettingsButton: true) {
      print("Settings tapped")
    }
  }
}
