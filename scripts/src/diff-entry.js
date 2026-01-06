/**
 * @pierre/diffs bundle entry point for ClaudeCodeUI
 *
 * This file is bundled with esbuild and loaded into a WKWebView.
 * It exposes the @pierre/diffs library and a bridge for Swift communication.
 */

import { FileDiff, parseDiffFromFile } from '@pierre/diffs';

// Global state
let currentDiffInstance = null;
let currentTheme = 'pierre-dark';
let currentDiffStyle = 'split';
let currentOverflow = 'scroll';

/**
 * Sends a message to Swift via webkit message handler
 */
function postToSwift(type, payload = {}) {
  if (window.webkit?.messageHandlers?.diffBridge) {
    window.webkit.messageHandlers.diffBridge.postMessage({
      type,
      ...payload,
    });
  } else {
    console.warn('Swift message handler not available');
  }
}

/**
 * Gets the container element, creating it if necessary
 */
function getContainer() {
  let container = document.getElementById('diff-container');
  if (!container) {
    container = document.createElement('div');
    container.id = 'diff-container';
    document.body.appendChild(container);
  }
  return container;
}

/**
 * Detects the language from a filename
 */
function detectLanguage(fileName) {
  if (!fileName) return undefined;

  const ext = fileName.split('.').pop()?.toLowerCase();
  const langMap = {
    // Swift & Apple
    swift: 'swift',
    m: 'objective-c',
    mm: 'objective-c',
    h: 'c',

    // JavaScript ecosystem
    js: 'javascript',
    jsx: 'jsx',
    ts: 'typescript',
    tsx: 'tsx',
    mjs: 'javascript',
    cjs: 'javascript',

    // Python
    py: 'python',
    pyw: 'python',
    pyi: 'python',

    // Go
    go: 'go',

    // Rust
    rs: 'rust',

    // Java & JVM
    java: 'java',
    kt: 'kotlin',
    kts: 'kotlin',
    scala: 'scala',

    // C family
    c: 'c',
    cpp: 'cpp',
    cc: 'cpp',
    cxx: 'cpp',
    hpp: 'cpp',
    hxx: 'cpp',

    // Ruby
    rb: 'ruby',
    erb: 'erb',

    // PHP
    php: 'php',

    // Shell
    sh: 'bash',
    bash: 'bash',
    zsh: 'bash',
    fish: 'fish',

    // Data formats
    json: 'json',
    yaml: 'yaml',
    yml: 'yaml',
    toml: 'toml',
    xml: 'xml',
    plist: 'xml',

    // Web
    html: 'html',
    htm: 'html',
    css: 'css',
    scss: 'scss',
    sass: 'sass',
    less: 'less',

    // Database
    sql: 'sql',

    // Markdown & docs
    md: 'markdown',
    mdx: 'mdx',
    rst: 'rst',

    // Config
    dockerfile: 'dockerfile',
    graphql: 'graphql',
    gql: 'graphql',

    // Other
    zig: 'zig',
    lua: 'lua',
    r: 'r',
    ps1: 'powershell',
    psm1: 'powershell',
  };

  // Handle special filenames
  const lowerFileName = fileName.toLowerCase();
  if (lowerFileName === 'dockerfile') return 'dockerfile';
  if (lowerFileName === 'makefile') return 'makefile';
  if (lowerFileName.endsWith('.d.ts')) return 'typescript';

  return langMap[ext] || undefined;
}

/**
 * Bridge object exposed to Swift
 */
window.pierreBridge = {
  /**
   * Renders a diff from input data
   * @param {object|string} inputData - Diff data (object or JSON string)
   */
  renderDiff(inputData) {
    try {
      // Handle both object (from base64 decode) and string input
      const input = typeof inputData === 'string' ? JSON.parse(inputData) : inputData;

      const { oldFile, newFile, options = {} } = input;

      // Clean up previous instance
      if (currentDiffInstance) {
        currentDiffInstance.cleanUp();
        currentDiffInstance = null;
      }

      // Clear container
      const container = getContainer();
      container.innerHTML = '';

      // Update current settings
      if (options.theme) {
        currentTheme = typeof options.theme === 'string' ? options.theme : options.theme.dark;
      }
      if (options.diffStyle) {
        currentDiffStyle = options.diffStyle;
      }
      if (options.overflow) {
        currentOverflow = options.overflow;
      }

      // Detect languages if not specified
      const oldLang = oldFile.lang || detectLanguage(oldFile.name);
      const newLang = newFile.lang || detectLanguage(newFile.name);

      // Create file objects for @pierre/diffs
      const oldFileObj = {
        name: oldFile.name || 'old',
        contents: oldFile.contents || '',
        lang: oldLang,
      };

      const newFileObj = {
        name: newFile.name || 'new',
        contents: newFile.contents || '',
        lang: newLang,
      };

      // Create FileDiff instance
      currentDiffInstance = new FileDiff({
        theme: {
          dark: 'pierre-dark',
          light: 'pierre-light',
        },
        themeType: currentTheme.includes('light') ? 'light' : 'dark',
        diffStyle: currentDiffStyle,
        diffIndicators: 'bars',
        hunkSeparators: 'line-info',
        lineDiffType: 'word-alt',
        overflow: currentOverflow,
        enableLineSelection: options.enableLineSelection ?? true,
        onLineClick: ({ lineNumber, side, event }) => {
          postToSwift('lineClicked', { lineNumber, side });
        },
        onLineSelectionEnd: (range) => {
          if (range) {
            postToSwift('selectionChanged', {
              startLine: range.start,
              endLine: range.end,
              side: range.side,
            });
          }
        },
      });

      // Render the diff
      currentDiffInstance.render({
        oldFile: oldFileObj,
        newFile: newFileObj,
        containerWrapper: container,
      });

      postToSwift('ready');
    } catch (error) {
      console.error('Error rendering diff:', error);
      postToSwift('error', { message: error.message });
    }
  },

  /**
   * Sets the current theme
   * @param {string} theme - "dark", "light", or "system"
   */
  setTheme(theme) {
    if (!currentDiffInstance) return;

    let themeType;
    if (theme === 'system') {
      themeType = window.matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
    } else {
      themeType = theme;
    }

    currentTheme = themeType === 'dark' ? 'pierre-dark' : 'pierre-light';
    currentDiffInstance.setThemeType(themeType);
  },

  /**
   * Sets the diff style
   * @param {string} style - "split" or "unified"
   */
  setDiffStyle(style) {
    if (!currentDiffInstance) return;

    currentDiffStyle = style;
    currentDiffInstance.setOptions({
      ...currentDiffInstance.options,
      diffStyle: style,
    });
    currentDiffInstance.rerender();
  },

  /**
   * Sets the overflow mode (wrap or scroll)
   * @param {string} mode - "wrap" or "scroll"
   */
  setOverflow(mode) {
    if (!currentDiffInstance) return;

    currentOverflow = mode;
    currentDiffInstance.setOptions({
      ...currentDiffInstance.options,
      overflow: mode,
    });
    currentDiffInstance.rerender();
  },

  /**
   * Scrolls to a specific line number
   * @param {number} lineNumber - The line number to scroll to
   */
  scrollToLine(lineNumber) {
    const lineElement = document.querySelector(`[data-line-index="${lineNumber - 1}"]`);
    if (lineElement) {
      lineElement.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
  },

  /**
   * Gets the currently selected text
   * @returns {string} The selected text
   */
  getSelection() {
    return window.getSelection()?.toString() || '';
  },

  /**
   * Cleans up the current diff instance
   */
  cleanup() {
    if (currentDiffInstance) {
      currentDiffInstance.cleanUp();
      currentDiffInstance = null;
    }
    const container = getContainer();
    container.innerHTML = '';
  },
};

// Also expose raw utilities for advanced usage
window.PierreDiffs = {
  FileDiff,
  parseDiffFromFile,
};

// Signal that the bridge is ready
document.addEventListener('DOMContentLoaded', () => {
  postToSwift('bridgeReady');
});

// Handle system theme changes
window.matchMedia('(prefers-color-scheme: dark)').addEventListener('change', (e) => {
  postToSwift('systemThemeChanged', { isDark: e.matches });
});
