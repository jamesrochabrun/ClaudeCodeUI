//
//  KeyboardShortcutManager.swift
//  ClaudeCodeUI
//
//  Created on 12/27/24.
//

import SwiftUI
import KeyboardShortcuts
import AppKit

@Observable
class KeyboardShortcutManager {
  var capturedText: String = ""
  var showCaptureAnimation = false
  
  init() {
    setupShortcuts()
    KeyboardShortcuts.enable([.captureWithC])
  }
  
  private func setupShortcuts() {
    // cmd+c
    KeyboardShortcuts.onKeyUp(for: .captureWithC) { [weak self] in
      Task { @MainActor in
        self?.captureSelectedText()
      }
    }
  }
  
  private func captureSelectedText() {
    // Get current selection from system clipboard
    let pasteboard = NSPasteboard.general
    let oldContents = pasteboard.string(forType: .string)
    
    // Simulate cmd+c to copy current selection
    let source = CGEventSource(stateID: .combinedSessionState)
    let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
    let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
    
    keyDown?.flags = .maskCommand
    keyUp?.flags = .maskCommand
    
    keyDown?.post(tap: .cghidEventTap)
    keyUp?.post(tap: .cghidEventTap)
    
    // Wait for clipboard to update
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
      if let selectedText = pasteboard.string(forType: .string),
         selectedText != oldContents {
        self?.capturedText = selectedText
        self?.showCaptureAnimation = true
        
        // Hide animation after 2 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
          self?.showCaptureAnimation = false
        }
        
        // Restore old clipboard contents
        if let oldContents = oldContents {
          pasteboard.clearContents()
          pasteboard.setString(oldContents, forType: .string)
        }
      }
    }
  }
}

// Define the keyboard shortcuts
extension KeyboardShortcuts.Name {
  static let captureWithC = Self("captureWithC", default: .init(.c, modifiers: [.command]))
}
