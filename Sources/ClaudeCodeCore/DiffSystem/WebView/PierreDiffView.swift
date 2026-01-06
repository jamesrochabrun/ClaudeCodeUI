//
//  PierreDiffView.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 1/6/26.
//

import SwiftUI
import WebKit

/// A SwiftUI view that renders code diffs using the @pierre/diffs JavaScript library.
///
/// This view wraps a WKWebView that loads a bundled JavaScript library for rendering
/// rich, syntax-highlighted diffs with features like:
/// - Split and unified view modes
/// - Syntax highlighting via Shiki
/// - Inline word-level change highlighting
/// - Dark/light theme support
public struct PierreDiffView: NSViewRepresentable {

  // MARK: - Properties

  /// The original file content (before changes)
  let oldContent: String

  /// The updated file content (after changes)
  let newContent: String

  /// The name of the file being diffed (used for syntax highlighting detection)
  let fileName: String

  /// The current diff view style
  @Binding var diffStyle: DiffStyle

  /// The current overflow mode (scroll or wrap)
  @Binding var overflowMode: OverflowMode

  /// Callback when the user clicks on a line
  var onLineClick: ((Int, String) -> Void)?

  /// Callback when the view requests expansion to full screen
  var onExpandRequest: (() -> Void)?

  // MARK: - Environment

  @Environment(\.colorScheme) private var colorScheme

  // MARK: - Initialization

  public init(
    oldContent: String,
    newContent: String,
    fileName: String,
    diffStyle: Binding<DiffStyle>,
    overflowMode: Binding<OverflowMode>,
    onLineClick: ((Int, String) -> Void)? = nil,
    onExpandRequest: (() -> Void)? = nil
  ) {
    self.oldContent = oldContent
    self.newContent = newContent
    self.fileName = fileName
    self._diffStyle = diffStyle
    self._overflowMode = overflowMode
    self.onLineClick = onLineClick
    self.onExpandRequest = onExpandRequest
  }

  // MARK: - NSViewRepresentable

  public func makeNSView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()

    // Set up message handler for JavaScript to Swift communication
    configuration.userContentController.add(
      context.coordinator,
      name: "diffBridge"
    )

    // Configure preferences
    configuration.preferences.setValue(true, forKey: "developerExtrasEnabled")

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.navigationDelegate = context.coordinator
    webView.allowsMagnification = true

    // Make background transparent to blend with SwiftUI
    webView.setValue(false, forKey: "drawsBackground")

    // Store reference in coordinator
    context.coordinator.webView = webView

    // Load the initial HTML
    loadHTML(into: webView)

    return webView
  }

  public func updateNSView(_ webView: WKWebView, context: Context) {
    let coordinator = context.coordinator

    // Check if content has changed
    let contentChanged = coordinator.lastOldContent != oldContent ||
                         coordinator.lastNewContent != newContent ||
                         coordinator.lastFileName != fileName

    // Check if style has changed
    let styleChanged = coordinator.lastDiffStyle != diffStyle

    // Check if overflow mode has changed
    let overflowChanged = coordinator.lastOverflowMode != overflowMode

    // Check if theme has changed
    let currentTheme = themeForColorScheme
    let themeChanged = coordinator.lastTheme != currentTheme

    if contentChanged {
      coordinator.lastOldContent = oldContent
      coordinator.lastNewContent = newContent
      coordinator.lastFileName = fileName
      coordinator.lastOverflowMode = overflowMode
      coordinator.renderDiff(
        oldContent: oldContent,
        newContent: newContent,
        fileName: fileName,
        theme: currentTheme,
        diffStyle: diffStyle,
        overflowMode: overflowMode
      )
    } else if styleChanged {
      coordinator.lastDiffStyle = diffStyle
      coordinator.setDiffStyle(diffStyle)
    } else if overflowChanged {
      coordinator.lastOverflowMode = overflowMode
      coordinator.setOverflow(overflowMode)
    } else if themeChanged {
      coordinator.lastTheme = currentTheme
      coordinator.setTheme(currentTheme)
    }
  }

  public func makeCoordinator() -> DiffWebViewCoordinator {
    DiffWebViewCoordinator(
      onLineClick: onLineClick,
      onExpandRequest: onExpandRequest
    )
  }

  // MARK: - Private Helpers

  private var themeForColorScheme: String {
    colorScheme == .dark ? "dark" : "light"
  }

  private func loadHTML(into webView: WKWebView) {
    let html = DiffHTMLTemplate.generateHTML()
    webView.loadHTMLString(html, baseURL: nil)
  }
}

// MARK: - DiffStyle

public enum DiffStyle: String, CaseIterable, Identifiable {
  case split
  case unified

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .split:
      return "Split"
    case .unified:
      return "Unified"
    }
  }
}

// MARK: - OverflowMode

public enum OverflowMode: String, CaseIterable, Identifiable {
  case scroll
  case wrap

  public var id: String { rawValue }

  public var displayName: String {
    switch self {
    case .scroll:
      return "Scroll"
    case .wrap:
      return "Wrap"
    }
  }
}
