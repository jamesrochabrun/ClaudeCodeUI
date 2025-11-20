//
//  KeyboardShortcutManager.swift
//  ClaudeCodeUI
//
//  Created on 12/27/24.
//

import SwiftUI
import KeyboardShortcuts
import AppKit
import Combine
import CCXcodeObserverServiceInterface
import Carbon.HIToolbox

@Observable
class KeyboardShortcutManager {
  var capturedText: String = ""
  var showCaptureAnimation = false
  var shouldFocusTextEditor = false
  var shouldRefreshObservation = false

  private let xcodeObserver: XcodeObserver
  private let xcodeObservationViewModel: XcodeObservationViewModel
  private let globalPreferences: GlobalPreferencesStorage
  private var stateSubscription: AnyCancellable?

  init(
    xcodeObserver: XcodeObserver,
    xcodeObservationViewModel: XcodeObservationViewModel,
    globalPreferences: GlobalPreferencesStorage
  ) {
    self.xcodeObserver = xcodeObserver
    self.xcodeObservationViewModel = xcodeObservationViewModel
    self.globalPreferences = globalPreferences
    setupShortcuts()
    setupXcodeObservation()
  }

  deinit {
    stateSubscription?.cancel()
  }
  
  private func setupShortcuts() {
    // cmd+i
    KeyboardShortcuts.onKeyUp(for: .captureWithI) { [weak self] in
      Task { @MainActor in
        self?.captureSelectedText()
      }
    }
  }

  private func setupXcodeObservation() {
    // Subscribe to Xcode state changes to enable/disable cmd+i hotkey
    stateSubscription = xcodeObserver.statePublisher
      .receive(on: DispatchQueue.main)
      .sink { [weak self] state in
        Task { @MainActor in
          self?.updateHotkeyState(for: state)
        }
      }

    // Set initial state
    Task { @MainActor in
      updateHotkeyState(for: xcodeObserver.state)
    }
  }

  @MainActor
  private func updateHotkeyState(for state: XcodeObserver.State) {
    // Enable cmd+i only when ALL conditions are met:
    // 1. User has enabled the shortcut in preferences
    // 2. Accessibility permissions are granted
    // 3. At least one Xcode instance is active

    let hasActiveXcode = state.knownState?.contains(where: { $0.isActive }) ?? false
    let hasPermission = xcodeObservationViewModel.hasAccessibilityPermission
    let isEnabledInPreferences = globalPreferences.enableXcodeShortcut

    let shouldEnable = isEnabledInPreferences && hasPermission && hasActiveXcode

    if shouldEnable {
      KeyboardShortcuts.enable([.captureWithI])
    } else {
      KeyboardShortcuts.disable([.captureWithI])
    }
  }

  private func captureSelectedText() {
    // Small delay to allow Xcode observation to update before clipboard capture
    // This ensures .focusedUIElementChanged notifications have time to process
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) { [weak self] in
      guard let self = self else { return }

      // Guard: Ensure all conditions are met before proceeding
      // This prevents crashes if handler fires during state transitions
      Task { @MainActor in
        guard self.xcodeObservationViewModel.hasAccessibilityPermission,
              self.globalPreferences.enableXcodeShortcut else {
          return
        }

        self.performClipboardCapture()
      }
    }
  }

  private func performClipboardCapture() {
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
      } else {
        // No selection - trigger observation refresh
        self?.shouldRefreshObservation = true
      }
    }
  }
}

// Define the keyboard shortcuts
extension KeyboardShortcuts.Name {
  static let captureWithI = Self(
    "captureWithI",
    default: .init(
      carbonKeyCode: Int(kVK_ANSI_I),  // Physical key position 0x22
      carbonModifiers: cmdKey           // Carbon modifier for Command key
    )
  )
}

