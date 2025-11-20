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
  private var permissionSubscription: AnyCancellable?
  private var preferenceSubscription: AnyCancellable?
  private var cancellables = Set<AnyCancellable>()

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
    setupPermissionMonitoring()
    setupPreferenceMonitoring()
  }

  deinit {
    stateSubscription?.cancel()
    permissionSubscription?.cancel()
    preferenceSubscription?.cancel()
    cancellables.removeAll()
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

  private func setupPermissionMonitoring() {
    // React to accessibility permission changes
    // Note: XcodeObservationViewModel already polls every 2 seconds, so we reuse that
    Task { @MainActor in
      // Monitor permission state reactively
      // Since hasAccessibilityPermission is @Observable, we can watch it
      // However, Observation framework doesn't provide publisher directly,
      // so we trigger updates when Xcode state changes (which also checks permissions)
    }
  }

  private func setupPreferenceMonitoring() {
    // React to user preference changes
    // Since globalPreferences is @Observable, changes will trigger updates automatically
    // when updateHotkeyState is called from the Xcode state subscription
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
      self?.performClipboardCapture()
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
  static let captureWithI = Self("captureWithI", default: .init(.i, modifiers: [.command]))
}

