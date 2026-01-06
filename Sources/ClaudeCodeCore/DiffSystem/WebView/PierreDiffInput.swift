//
//  PierreDiffInput.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 1/6/26.
//

import Foundation

/// Input data structure for rendering diffs with @pierre/diffs.
/// This matches the JavaScript library's expected format.
struct PierreDiffInput: Codable {

  /// Represents a file's contents for diff comparison.
  struct FileContents: Codable {
    /// The filename (used for display and language detection)
    let name: String

    /// The file's text content
    let contents: String

    /// Optional language override for syntax highlighting.
    /// If nil, language is auto-detected from filename.
    let lang: String?
  }

  /// Configuration options for the diff renderer.
  struct Options: Codable {
    /// Theme configuration for dark/light modes
    let theme: ThemeConfig

    /// Diff view style: "split" or "unified"
    let diffStyle: String

    /// Overflow mode: "scroll" or "wrap"
    let overflow: String

    /// Enable click-to-select on line numbers
    let enableLineSelection: Bool
  }

  /// Theme configuration supporting dark and light modes.
  struct ThemeConfig: Codable {
    /// Theme name for dark mode (e.g., "pierre-dark")
    let dark: String

    /// Theme name for light mode (e.g., "pierre-light")
    let light: String
  }

  /// The original file (before changes)
  let oldFile: FileContents

  /// The new file (after changes)
  let newFile: FileContents

  /// Rendering options
  let options: Options
}

// MARK: - Convenience Initializers

extension PierreDiffInput {

  /// Creates a PierreDiffInput from a DiffResult.
  ///
  /// - Parameters:
  ///   - diffResult: The diff result containing original and updated content
  ///   - diffStyle: The style to use for rendering
  ///   - overflowMode: The overflow mode (scroll or wrap)
  /// - Returns: A configured PierreDiffInput
  static func from(
    diffResult: DiffResult,
    diffStyle: DiffStyle = .split,
    overflowMode: OverflowMode = .scroll
  ) -> PierreDiffInput {
    PierreDiffInput(
      oldFile: FileContents(
        name: diffResult.fileName,
        contents: diffResult.original,
        lang: nil
      ),
      newFile: FileContents(
        name: diffResult.fileName,
        contents: diffResult.updated,
        lang: nil
      ),
      options: Options(
        theme: ThemeConfig(
          dark: "pierre-dark",
          light: "pierre-light"
        ),
        diffStyle: diffStyle.rawValue,
        overflow: overflowMode.rawValue,
        enableLineSelection: true
      )
    )
  }
}
