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
  var shouldFocusTextEditor = false
  
  init() {
    setupShortcuts()
    KeyboardShortcuts.enable([.captureWithI])
  }
  
  private func setupShortcuts() {
    // cmd+i
    KeyboardShortcuts.onKeyUp(for: .captureWithI) { [weak self] in
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
        
        // Activate the app more reliably
        NSRunningApplication.current.activate()
        
        // Ensure window comes to front
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
          // Find and activate the key window
          if let keyWindow = NSApplication.shared.keyWindow ?? NSApplication.shared.windows.first {
            keyWindow.makeKeyAndOrderFront(nil)
          }
        }
        
        // Trigger focus on text editor
        self?.shouldFocusTextEditor = true
        
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
  static let captureWithI = Self("captureWithI", default: .init(.i, modifiers: [.command]))
}

