//
//  DiffHTMLTemplate.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 1/6/26.
//

import Foundation

/// Generates the HTML template for the Pierre Diff WebView.
enum DiffHTMLTemplate {

  /// Generates the complete HTML string with embedded JavaScript and CSS.
  static func generateHTML() -> String {
    let bundleJS = loadBundledJavaScript()

    return """
    <!DOCTYPE html>
    <html>
    <head>
        <meta charset="UTF-8">
        <meta name="viewport" content="width=device-width, initial-scale=1.0">
        <style>
            \(styles)
        </style>
    </head>
    <body>
        <div id="diff-container"></div>
        <script>
            \(bundleJS)
        </script>
    </body>
    </html>
    """
  }

  // MARK: - Private

  /// Loads the bundled JavaScript from the app resources.
  private static func loadBundledJavaScript() -> String {
    // Try to load from bundle resources
    guard let bundleURL = Bundle.module.url(
      forResource: "pierre-diffs-bundle",
      withExtension: "js",
      subdirectory: "Resources"
    ) else {
      AppLogger.error("DiffHTMLTemplate: Could not find pierre-diffs-bundle.js in bundle")
      return fallbackJavaScript
    }

    do {
      let content = try String(contentsOf: bundleURL, encoding: .utf8)
      return content
    } catch {
      AppLogger.error("DiffHTMLTemplate: Failed to load pierre-diffs-bundle.js: \(error)")
      return fallbackJavaScript
    }
  }

  /// Fallback JavaScript when bundle loading fails
  private static let fallbackJavaScript = """
  window.pierreBridge = {
    renderDiff: function(input) {
      const container = document.getElementById('diff-container');
      container.innerHTML = '<div style="color: red; padding: 20px;">Failed to load diff library. Please restart the application.</div>';
      if (window.webkit?.messageHandlers?.diffBridge) {
        window.webkit.messageHandlers.diffBridge.postMessage({ type: 'error', message: 'Bundle not loaded' });
      }
    },
    setTheme: function() {},
    setDiffStyle: function() {},
    scrollToLine: function() {},
    getSelection: function() { return ''; },
    cleanup: function() {}
  };
  """

  /// CSS styles for the diff view
  private static let styles = """
  * {
    box-sizing: border-box;
  }

  :root {
    --diffs-font-family: ui-monospace, 'SF Mono', Menlo, Monaco, 'Cascadia Code', 'Roboto Mono', monospace;
    --diffs-font-size: 12px;
    --diffs-line-height: 1.5;
    --diffs-tab-size: 2;
    --diffs-header-font-family: -apple-system, BlinkMacSystemFont, 'Helvetica Neue', sans-serif;
    --diffs-min-number-column-width: 4ch;
  }

  html, body {
    margin: 0;
    padding: 0;
    height: 100%;
    width: 100%;
    overflow: hidden;
    font-family: var(--diffs-font-family);
    font-size: var(--diffs-font-size);
    line-height: var(--diffs-line-height);
    -webkit-font-smoothing: antialiased;
    -moz-osx-font-smoothing: grayscale;
  }

  body {
    background-color: transparent;
  }

  #diff-container {
    width: 100%;
    height: 100%;
    overflow: auto;
  }

  /* Scrollbar styling for macOS feel */
  ::-webkit-scrollbar {
    width: 8px;
    height: 8px;
  }

  ::-webkit-scrollbar-track {
    background: transparent;
  }

  ::-webkit-scrollbar-thumb {
    background-color: rgba(128, 128, 128, 0.3);
    border-radius: 4px;
  }

  ::-webkit-scrollbar-thumb:hover {
    background-color: rgba(128, 128, 128, 0.5);
  }

  /* Dark mode adjustments */
  @media (prefers-color-scheme: dark) {
    ::-webkit-scrollbar-thumb {
      background-color: rgba(255, 255, 255, 0.2);
    }

    ::-webkit-scrollbar-thumb:hover {
      background-color: rgba(255, 255, 255, 0.3);
    }
  }

  /* Selection styling */
  ::selection {
    background-color: rgba(59, 130, 246, 0.3);
  }

  /* Hide file header if desired */
  .diffs-header {
    display: none;
  }
  """
}
