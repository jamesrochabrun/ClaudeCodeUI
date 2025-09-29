//
//  PermissionModeIndicator.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 2025.
//

import SwiftUI
import ClaudeCodeSDK

// MARK: - Extensions for ClaudeCodeSDK.PermissionMode

extension ClaudeCodeSDK.PermissionMode {
  
  var tip: String { "(shift+tab to cycle)" }
  
  /// Human-readable display name for the mode
  public var displayName: String {
    switch self {
    case .default:
      return "default \(tip)"
    case .plan:
      return "plan mode on \(tip)"
    case .acceptEdits:
      return "accept edits on \(tip)"
    case .bypassPermissions:
      return "bypass permissions \(tip)"
    }
  }
  
  /// Short description of what the mode does
  public var description: String {
    switch self {
    case .default:
      return "Normal permission checks"
    case .plan:
      return "Plan before execution"
    case .acceptEdits:
      return "Auto-accept file edits"
    case .bypassPermissions:
      return "No permission prompts"
    }
  }
  
  /// Icon name for the mode
  public var iconName: String {
    switch self {
    case .default:
      return "shield"
    case .plan:
      return "doc.plaintext"
    case .acceptEdits:
      return "forward.fill"
    case .bypassPermissions:
      return "shield.slash"
    }
  }

  /// Returns the next mode in the cycle for keyboard shortcut toggling
  public var nextMode: ClaudeCodeSDK.PermissionMode {
    let allCases: [ClaudeCodeSDK.PermissionMode] = [.default, .plan, .acceptEdits, .bypassPermissions]
    guard let currentIndex = allCases.firstIndex(of: self) else { return .default }
    let nextIndex = (currentIndex + 1) % allCases.count
    return allCases[nextIndex]
  }
}

/// A view that displays the current permission mode
public struct PermissionModeIndicator: View {
  let mode: ClaudeCodeSDK.PermissionMode
  let isCompact: Bool
  
  public init(mode: ClaudeCodeSDK.PermissionMode, isCompact: Bool = false) {
    self.mode = mode
    self.isCompact = isCompact
  }
  
  public var body: some View {
    HStack(spacing: 4) {
      Image(systemName: mode.iconName)
        .font(.system(size: isCompact ? 10 : 11))
        .foregroundColor(modeColor)
      
      if !isCompact {
        Text(mode.displayName)
          .font(.system(size: 11))
          .foregroundColor(modeColor)
      }
    }
    .padding(.horizontal, isCompact ? 4 : 6)
    .padding(.vertical, 2)
    .background(modeColor.opacity(0.1))
    .cornerRadius(4)
    .overlay(
      RoundedRectangle(cornerRadius: 4)
        .stroke(modeColor.opacity(0.3), lineWidth: 0.5)
    )
    .help(mode.description)
  }
  
  private var modeColor: Color {
    switch mode {
    case .default:
      return .gray
    case .plan:
      return .teal
    case .acceptEdits:
      return .purple
    case .bypassPermissions:
      return .orange
    }
  }
}

/// A button that shows the current permission mode and allows cycling through modes
public struct PermissionModeButton: View {
  @Binding var mode: ClaudeCodeSDK.PermissionMode
  
  public init(
    mode: Binding<ClaudeCodeSDK.PermissionMode>)
  {
    _mode = mode
  }
  
  public var body: some View {
    Button(action: toggleMode) {
      PermissionModeIndicator(mode: mode)
    }
    .buttonStyle(.plain)
    .help("Permission Mode: \(mode.description)\n⌘⇧ to cycle modes")
  }
  
  private func toggleMode() {
    let newMode = mode.nextMode
    mode = newMode
  }
}

#Preview {
  VStack(spacing: 20) {
    let allModes: [ClaudeCodeSDK.PermissionMode] = [.default, .plan, .acceptEdits, .bypassPermissions]
    ForEach(allModes, id: \.self) { mode in
      HStack {
        PermissionModeIndicator(mode: mode)
        PermissionModeIndicator(mode: mode, isCompact: true)
      }
    }
    
    Divider()
    
    PermissionModeButton(mode: .constant(.default))
  }
  .padding()
}
