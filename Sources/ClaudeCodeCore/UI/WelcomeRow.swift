//
//  WelcomeRow.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 6/21/25.
//

import Foundation
import SwiftUI
import AppKit

struct WelcomeRow: View {
  let path: String?
  let showSettingsButton: Bool
  let appName: String
  let onSettingsTapped: () -> Void
  
  // Custom color
  init(
    path: String?,
    showSettingsButton: Bool = false,
    appName: String = "Claude Code UI",
    onSettingsTapped: @escaping () -> Void = {}
  ) {
    self.path = path
    self.showSettingsButton = showSettingsButton
    self.appName = appName
    self.onSettingsTapped = onSettingsTapped
  }
  
  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 6) {
      Text("✻")
        .foregroundColor(.bookCloth)
      VStack(alignment: .leading, spacing: 16) {
        Text("Welcome to **\(appName)!**")
          .font(.system(.body, design: .monospaced))
          .foregroundColor(.primary)
        
        if showSettingsButton {
          VStack(alignment: .leading, spacing: 8) {
            Text("No working directory selected")
              .font(.system(.caption, design: .monospaced))
              .foregroundColor(.orange)
            
            Button(action: onSettingsTapped) {
              HStack(spacing: 4) {
                Image(systemName: "folder.badge.plus")
                  .font(.system(size: 14))
                Text("Select Working Directory")
                  .font(.system(.body, design: .monospaced))
              }
              .foregroundColor(.bookCloth)
              .padding(.horizontal, 12)
              .padding(.vertical, 6)
              .background(Color.bookCloth.opacity(0.1))
              .cornerRadius(6)
            }
            .buttonStyle(.plain)
            .help("Select a working directory for this session")
          }
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
    WelcomeRow(path: "cwd: /Users/jamesrochabrun/Desktop/git/ClaudeCodeUI", appName: "Claude Code UI")
    WelcomeRow(path: nil, showSettingsButton: true, appName: "My App") {
      print("Settings tapped")
    }
  }
}
