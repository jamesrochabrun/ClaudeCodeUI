//
//  DiffView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import SwiftUI
import TerminalService

/// A view that displays a GitHub-style diff
struct DiffView: View {
  
  // MARK: - Properties
  
  @State private var diffViewModel: DiffViewModel
  let oldContent: String
  let newContent: String
  let fileName: String?
  
  @State private var isExpanded = true
  @State private var showLineNumbers = true
  
  // MARK: - Initialization
  
  init(
    oldContent: String,
    newContent: String,
    fileName: String? = nil,
    diffService: DiffService
  ) {
    self.oldContent = oldContent
    self.newContent = newContent
    self.fileName = fileName
    self._diffViewModel = State(initialValue: DiffViewModel(diffService: diffService))
  }
  
  // MARK: - Body
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      diffHeader
      
      if isExpanded {
        // Diff content
        if diffViewModel.isLoading {
          ProgressView()
            .frame(maxWidth: .infinity, minHeight: 100)
            .background(Color.gray.opacity(0.1))
        } else if let error = diffViewModel.error {
          Text(error)
            .foregroundColor(.red)
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1))
        } else {
          ScrollView(.horizontal, showsIndicators: true) {
            VStack(alignment: .leading, spacing: 0) {
              ForEach(diffViewModel.diffLines) { line in
                DiffLineView(
                  line: line,
                  showLineNumbers: showLineNumbers
                )
              }
            }
            .background(Color(nsColor: .textBackgroundColor))
          }
          .background(Color(nsColor: .controlBackgroundColor))
          .cornerRadius(4)
        }
      }
    }
    .task {
      await diffViewModel.generateDiff(
        oldContent: oldContent,
        newContent: newContent,
        fileName: fileName
      )
    }
  }
  
  // MARK: - Subviews
  
  private var diffHeader: some View {
    HStack {
      Button(action: { isExpanded.toggle() }) {
        HStack(spacing: 4) {
          Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 10))
          
          if let fileName = fileName {
            Label(fileName, systemImage: "doc.text")
              .font(.system(.body, design: .monospaced))
          } else {
            Text("Diff")
              .font(.system(.body, design: .monospaced))
          }
          
          // Statistics
          if !diffViewModel.isLoading && diffViewModel.error == nil {
            HStack(spacing: 8) {
              Text("+\(diffViewModel.additions)")
                .foregroundColor(.green)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
              
              Text("-\(diffViewModel.deletions)")
                .foregroundColor(.red)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
            }
            .padding(.horizontal, 8)
          }
        }
      }
      .buttonStyle(.plain)
      
      Spacer()
      
      if isExpanded {
        Button(action: { showLineNumbers.toggle() }) {
          Image(systemName: showLineNumbers ? "number" : "number.square")
            .font(.system(size: 12))
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        .help(showLineNumbers ? "Hide line numbers" : "Show line numbers")
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(4)
  }
}

// MARK: - DiffLineView

struct DiffLineView: View {
  let line: DiffLine
  let showLineNumbers: Bool
  
  private let lineNumberWidth: CGFloat = 45
  
  var body: some View {
    HStack(spacing: 0) {
      if showLineNumbers {
        // Line numbers
        HStack(spacing: 0) {
          // Old line number
          Text(line.oldLineNumber.map { String($0) } ?? "")
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.secondary)
            .frame(width: lineNumberWidth, alignment: .trailing)
            .padding(.trailing, 4)
          
          // New line number
          Text(line.newLineNumber.map { String($0) } ?? "")
            .font(.system(size: 11, design: .monospaced))
            .foregroundColor(.secondary)
            .frame(width: lineNumberWidth, alignment: .trailing)
            .padding(.trailing, 8)
        }
        .background(Color.gray.opacity(0.05))
      }
      
      // Prefix symbol
      Text(line.type.prefixSymbol)
        .font(.system(size: 12, design: .monospaced))
        .foregroundColor(line.type.foregroundColor)
        .frame(width: 12)
      
      // Content
      Text(line.content)
        .font(.system(size: 12, design: .monospaced))
        .foregroundColor(line.type.foregroundColor)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.trailing, 12)
    }
    .frame(maxWidth: .infinity)
    .background(line.type.backgroundColor)
  }
}

// MARK: - Preview

#Preview {
  DiffView(
    oldContent: """
    func hello() {
        print("Hello")
    }
    """,
    newContent: """
    func hello() {
        print("Hello, World!")
        print("Welcome")
    }
    """,
    fileName: "example.swift",
    diffService: DiffService(terminalService: DefaultTerminalService())
  )
  .frame(width: 600, height: 400)
  .padding()
}