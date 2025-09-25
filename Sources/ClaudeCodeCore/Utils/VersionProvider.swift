//
//  VersionProvider.swift
//  ClaudeCodeUI
//
//  Created on 2025-09-25.
//

import Foundation

enum VersionProvider {
  static let fallbackVersion = "1.1.0"

  static var appVersion: String {
    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String {
      return version
    }

    if let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String {
      return version
    }

    if ProcessInfo.processInfo.environment["XCODE_VERSION_MAJOR"] != nil {
      return "\(fallbackVersion)-dev"
    }

    return fallbackVersion
  }

  static var formattedVersion: String {
    "Version \(appVersion)"
  }

  static var buildNumber: String? {
    Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
  }

  static var fullVersionString: String {
    if let build = buildNumber, build != appVersion {
      return "Version \(appVersion) (\(build))"
    }
    return formattedVersion
  }
}