//
//  PreferencesLoadError.swift
//  ClaudeCodeUI
//
//  Created on 1/18/25.
//

import Foundation

/// Represents different states of preferences loading
public enum PreferencesLoadState: Equatable {
  /// Preferences loaded successfully
  case loaded
  /// No preferences file exists (first run or deleted)
  case notFound
  /// Preferences file exists but is corrupted
  case corrupted(PreferencesLoadError)
  
  public static func == (lhs: PreferencesLoadState, rhs: PreferencesLoadState) -> Bool {
    switch (lhs, rhs) {
    case (.loaded, .loaded), (.notFound, .notFound):
      return true
    case let (.corrupted(error1), .corrupted(error2)):
      return error1.localizedDescription == error2.localizedDescription
    default:
      return false
    }
  }
}

/// Specific errors that can occur when loading preferences
public enum PreferencesLoadError: LocalizedError {
  /// File exists but contains invalid JSON
  case invalidJSON(underlying: Error)
  /// File exists but data structure doesn't match expected format
  case invalidFormat(details: String)
  /// File exists but is empty or contains no data
  case emptyFile
  /// File system error (permissions, etc.)
  case fileSystemError(underlying: Error)
  /// Unknown corruption
  case unknownCorruption(underlying: Error)
  
  public var errorDescription: String? {
    switch self {
    case .invalidJSON:
      return "Preferences file contains invalid data and cannot be read"
    case .invalidFormat(let details):
      return "Preferences file format is incorrect: \(details)"
    case .emptyFile:
      return "Preferences file is empty"
    case .fileSystemError:
      return "Could not access preferences file due to system error"
    case .unknownCorruption:
      return "Preferences file is corrupted"
    }
  }
  
  public var recoverySuggestion: String? {
    switch self {
    case .invalidJSON, .invalidFormat, .emptyFile, .unknownCorruption:
      return "Reset preferences to start fresh with safe defaults"
    case .fileSystemError:
      return "Check file permissions and try again"
    }
  }
  
  /// Detailed technical description for logging
  public var technicalDescription: String {
    switch self {
    case .invalidJSON(let error):
      return "JSON parsing failed: \(error)"
    case .invalidFormat(let details):
      return "Format validation failed: \(details)"
    case .emptyFile:
      return "File has 0 bytes or only whitespace"
    case .fileSystemError(let error):
      return "File system error: \(error)"
    case .unknownCorruption(let error):
      return "Unknown corruption: \(error)"
    }
  }
}
