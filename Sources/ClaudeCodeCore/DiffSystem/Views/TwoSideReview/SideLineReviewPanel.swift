//
//  SideLineReviewPanel.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/2/25.
//

import Foundation
import SwiftUI

enum ViewSide {
  case left
  case right
}

// MARK: - SideLineReviewPanel

struct SideLineReviewPanel: View {
  
  // MARK: Internal
  
  let sideLine: SideLine
  let side: ViewSide
  
  var body: some View {
    HStack(alignment: .firstTextBaseline, spacing: 0) {
      LineNumberView(
        lineNumber: side == .left ? sideLine.originalLineNumber : sideLine.updatedLineNumber,
        side: side
      )
      LineContentView(
        text: sideLine.text,
        shouldShowText: styleCalculator.shouldShowText,
        shouldShowBackground: styleCalculator.shouldShowBackground,
        backgroundColor: styleCalculator.backgroundColor
      )
    }
  }
  
  // MARK: Private
  
  @Environment(\.colorScheme) private var colorScheme
  
  private var styleCalculator: DiffStyleCalculator {
    DiffStyleCalculator(
      sideLine: sideLine,
      side: side,
      colorScheme: colorScheme
    )
  }
}


// MARK: - LineNumberView

private struct LineNumberView: View {
  let lineNumber: Int?
  let side: ViewSide
  
  var body: some View {
    Group {
      if let lineNumber {
        Text("\(lineNumber)")
          .font(.system(.body, design: .monospaced))
          .foregroundColor(.gray)
          .frame(width: 40, alignment: side == .left ? .leading : .trailing)
          .padding(.horizontal, 4)
      } else {
        Text("")
          .frame(width: 40, alignment: .leading)
          .padding(.horizontal, 4)
      }
    }
  }
}

// MARK: - LineContentView

private struct LineContentView: View {
  let text: String
  let shouldShowText: Bool
  let shouldShowBackground: Bool
  let backgroundColor: Color
  
  var body: some View {
    Text(text)
      .textSelection(.enabled)
      .font(.system(.body, design: .monospaced))
      .padding(.vertical, 2)
      .padding(.horizontal, 4)
      .frame(maxWidth: .infinity, alignment: .leading)
      .opacity(shouldShowText ? 1 : 0)
      .background(shouldShowBackground ? backgroundColor : .clear)
  }
}

// MARK: - DiffStyleCalculator

private struct DiffStyleCalculator {
  let sideLine: SideLine
  let side: ViewSide
  let colorScheme: ColorScheme
  
  var shouldShowText: Bool {
    switch (sideLine.type, side) {
    case (.unchanged, _):
      true
    case (.deleted, .left):
      true
    case (.inserted, .right):
      true
    default:
      false
    }
  }
  
  var shouldShowBackground: Bool {
    switch (sideLine.type, side) {
    case (.unchanged, _):
      false
    case (.deleted, .left):
      true
    case (.inserted, .right):
      true
    case (.deleted, .right), (.inserted, .left):
      true
    default:
      false
    }
  }
  
  var backgroundColor: Color {
    switch (sideLine.type, side) {
    case (.deleted, .left):
      DiffColors.backgroundColorForRemovedLines(in: colorScheme)
    case (.inserted, .right):
      DiffColors.backgroundColorForAddedLines(in: colorScheme)
    case (.deleted, .right), (.inserted, .left):
      Color.gray.opacity(0.15)
    default:
        .clear
    }
  }
}
