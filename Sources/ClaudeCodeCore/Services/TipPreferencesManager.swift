//
//  TipPreferencesManager.swift
//  ClaudeCodeUI
//
//  Created on 11/7/24.
//

import Foundation

/// Manages user preferences for dismissable tips with versioning support
final class TipPreferencesManager: ObservableObject {

  // MARK: - Constants

  private static let dismissedTipsKey = "TipPreferences.dismissedTips"

  // MARK: - Properties

  private let userDefaults: UserDefaults

  // MARK: - Initialization

  init(userDefaults: UserDefaults = .standard) {
    self.userDefaults = userDefaults
  }

  // MARK: - Tip Identifiers

  enum TipID: String, Codable, CaseIterable {
    case cmdITipV1 = "tip-cmd-i-v1"

    var displayMessage: String {
      switch self {
      case .cmdITipV1:
        return "Press Cmd+I to capture code selection or send active file to context"
      }
    }

    var iconName: String {
      switch self {
      case .cmdITipV1:
        return "command.circle"
      }
    }
  }

  // MARK: - Private Helpers

  private var dismissedTips: Set<String> {
    guard let jsonString = userDefaults.string(forKey: Self.dismissedTipsKey),
          let data = jsonString.data(using: .utf8),
          let tips = try? JSONDecoder().decode(Set<String>.self, from: data) else {
      return []
    }
    return tips
  }

  private func saveDismissedTips(_ tips: Set<String>) {
    guard let data = try? JSONEncoder().encode(tips),
          let jsonString = String(data: data, encoding: .utf8) else {
      return
    }
    userDefaults.set(jsonString, forKey: Self.dismissedTipsKey)
  }

  // MARK: - Public Methods

  /// Checks if a tip has been dismissed by the user
  func isDismissed(_ tipID: TipID) -> Bool {
    return dismissedTips.contains(tipID.rawValue)
  }

  /// Marks a tip as dismissed
  func dismiss(_ tipID: TipID) {
    var tips = dismissedTips
    tips.insert(tipID.rawValue)
    saveDismissedTips(tips)
    objectWillChange.send()
  }

  /// Resets all dismissed tips (useful for debugging/testing)
  func reset() {
    userDefaults.removeObject(forKey: Self.dismissedTipsKey)
    objectWillChange.send()
  }

  /// Undismisses a specific tip (useful for testing new versions)
  func undismiss(_ tipID: TipID) {
    var tips = dismissedTips
    tips.remove(tipID.rawValue)
    saveDismissedTips(tips)
    objectWillChange.send()
  }
}
