//
//  InlineFileSearchView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 2025-07-01.
//

import SwiftUI

/// Displays inline file search results for @ mentions
struct InlineFileSearchView: View {
  @Bindable var viewModel: FileSearchViewModel
  let onSelect: (FileResult) -> Void
  let onDismiss: () -> Void
  
  @State private var hoveredIndex: Int? = nil
  
  // MARK: - Computed Properties
  
  private var shouldShowEmptyState: Bool {
    viewModel.searchResults.isEmpty &&
    !viewModel.searchQuery.isEmpty &&
    !viewModel.isSearching
  }
  
  // MARK: - Body
  
  var body: some View {
    VStack(spacing: 0) {
      headerBar
      if !viewModel.searchQuery.isEmpty {
        Divider()
        resultsArea
      }
    }
    .background(Color(NSColor.controlBackgroundColor))
  }
  
  // MARK: - Subviews
  
  private var headerBar: some View {
    HeaderBar(
      searchQuery: viewModel.searchQuery,
      isSearching: viewModel.isSearching,
      resultsCount: viewModel.searchResults.count,
      onDismiss: onDismiss
    )
  }
  
  private var resultsArea: some View {
    Group {
      if shouldShowEmptyState {
        emptyStateView
      } else {
        VStack(spacing: 0) {
          searchResultsList
          if !viewModel.searchResults.isEmpty {
            Label("Use ↑↓ to navigate, Enter to select, Esc to cancel", systemImage: "keyboard")
              .font(.caption2)
              .foregroundColor(.secondary)
              .padding(.bottom, 8)
          }
        }
      }
    }
  }
  
  private var searchResultsList: some View {
    ScrollViewReader { proxy in
      ScrollView {
        VStack(spacing: 0) {
          ForEach(Array(viewModel.searchResults.enumerated()), id: \.element.id) { index, result in
            resultRow(for: result, at: index)
            
            if index < viewModel.searchResults.count - 1 {
              Divider().padding(.leading, 40)
            }
          }
        }
        .padding(.bottom, 4)
      }
      .frame(maxHeight: 220)
      .fixedSize(horizontal: false, vertical: true)
      .onChange(of: viewModel.selectedIndex, handleSelectionChange(proxy))
    }
  }
  
  private func resultRow(for result: FileResult, at index: Int) -> some View {
    FileSearchResultRow(
      result: result,
      isSelected: index == viewModel.selectedIndex,
      isHovered: index == hoveredIndex,
      searchQuery: viewModel.searchQuery
    )
    .id(result.id)
    .onTapGesture { 
      viewModel.selectedIndex = index
      onSelect(result) 
    }
    .onHover { handleHover($0, at: index) }
  }
  
  // MARK: - Helper Methods
  
  private func handleHover(_ isHovering: Bool, at index: Int) {
    hoveredIndex = isHovering ? index : nil
    // Don't update selection on hover - let keyboard navigation work independently
  }
  
  private func handleSelectionChange(_ proxy: ScrollViewProxy) -> (Int, Int) -> Void {
    return { _, newIndex in
      if newIndex >= 0 && newIndex < viewModel.searchResults.count {
        withAnimation(.easeInOut(duration: 0.1)) {
          proxy.scrollTo(viewModel.searchResults[newIndex].id, anchor: .center)
        }
      }
    }
  }
  
  private var emptyStateView: some View {
    VStack(spacing: 8) {
      Image(systemName: "magnifyingglass")
        .font(.title2)
        .foregroundColor(.secondary)
      
      Text("No files found for '\(viewModel.searchQuery)'")
        .font(.body)
        .foregroundColor(.secondary)
      
      Text("Try a different search term")
        .font(.caption)
        .foregroundColor(Color.secondary.opacity(0.6))
    }
    .padding(.vertical, 30)
    .frame(maxWidth: .infinity, minHeight: 100)
  }
}

// MARK: - File Search Result Row

private struct FileSearchResultRow: View {
  let result: FileResult
  let isSelected: Bool
  let isHovered: Bool
  let searchQuery: String
  
  @Environment(\.colorScheme) private var colorScheme
  
  private var backgroundColor: Color {
    if isSelected {
      return Color.accentColor.opacity(0.3)
    } else if isHovered {
      return Color.gray.opacity(0.1)
    }
    return Color.clear
  }
  
  private var iconColor: Color {
    // Use file extension to determine icon color
    switch result.fileExtension {
    case "swift":
      return .orange
    case "js", "jsx", "ts", "tsx":
      return .yellow
    case "py":
      return .blue
    case "rb":
      return .red
    case "go":
      return .cyan
    case "rs":
      return .brown
    case "java", "kt":
      return .purple
    case "cs":
      return .green
    case "md":
      return .gray
    default:
      return .secondary
    }
  }
  
  private var fileIcon: String {
    switch result.fileExtension {
    case "swift":
      return "swift"
    case "folder":
      return "folder"
    case "md":
      return "doc.richtext"
    case "json", "yml", "yaml", "xml":
      return "doc.badge.gearshape"
    default:
      return "doc.text"
    }
  }
  
  var body: some View {
    HStack(spacing: 12) {
      fileIconView
      fileInfoView
      Spacer()
      selectionIndicator
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(backgroundColor)
    .contentShape(Rectangle())
  }
  
  // MARK: - Subviews
  
  private var fileIconView: some View {
    Image(systemName: fileIcon)
      .font(.body)
      .foregroundColor(iconColor)
      .frame(width: 20)
  }
  
  private var fileInfoView: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(result.fileName)
        .font(.body)
        .fontWeight(.medium)
        .foregroundColor(.primary)
      
      Text(result.filePath)
        .font(.caption)
        .foregroundColor(.secondary)
        .lineLimit(1)
        .truncationMode(.middle)
    }
  }
  
  @ViewBuilder
  private var selectionIndicator: some View {
    if isSelected {
      Image(systemName: "chevron.right")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }
}

// MARK: - Header Bar Component

private struct HeaderBar: View {
  let searchQuery: String
  let isSearching: Bool
  let resultsCount: Int
  let onDismiss: () -> Void
  
  var body: some View {
    HStack {
      searchLabel
      Spacer()
      statusSection
      dismissButton
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color(NSColor.separatorColor).opacity(0.1))
  }
  
  private var searchLabel: some View {
    Label("Searching for: @\(searchQuery)", systemImage: "magnifyingglass")
      .font(.caption)
      .foregroundColor(.secondary)
  }
  
  private var statusSection: some View {
    HStack(spacing: 8) {
      if isSearching {
        ProgressView()
          .scaleEffect(0.8)
          .frame(width: 16, height: 16)
      }
      
      Text("\(resultsCount) results")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }
  
  private var dismissButton: some View {
    Button(action: onDismiss) {
      Image(systemName: "xmark.circle.fill")
        .foregroundColor(.secondary)
        .font(.system(size: 14))
    }
    .buttonStyle(.plain)
  }
}

// MARK: - Highlighted Text View

private struct HighlightedText: View {
  let text: String
  let highlights: [Range<String.Index>]
  let baseColor: Color
  let highlightColor: Color
  let font: Font
  let isBold: Bool
  
  var body: some View {
    HStack(spacing: 0) {
      ForEach(Array(textSegments.enumerated()), id: \.offset) { _, segment in
        Text(segment.text)
          .font(font)
          .fontWeight(segment.isHighlighted && isBold ? .bold : .regular)
          .foregroundColor(segment.isHighlighted ? highlightColor : baseColor)
      }
    }
  }
  
  private var textSegments: [(text: String, isHighlighted: Bool)] {
    var segments: [(text: String, isHighlighted: Bool)] = []
    var currentIndex = text.startIndex
    
    // Sort highlights by start position
    let sortedHighlights = highlights.sorted { $0.lowerBound < $1.lowerBound }
    
    for highlight in sortedHighlights {
      // Add non-highlighted text before this highlight
      if currentIndex < highlight.lowerBound {
        let nonHighlightedText = String(text[currentIndex..<highlight.lowerBound])
        segments.append((text: nonHighlightedText, isHighlighted: false))
      }
      
      // Add highlighted text
      let highlightedText = String(text[highlight])
      segments.append((text: highlightedText, isHighlighted: true))
      
      currentIndex = highlight.upperBound
    }
    
    // Add any remaining non-highlighted text
    if currentIndex < text.endIndex {
      let remainingText = String(text[currentIndex..<text.endIndex])
      segments.append((text: remainingText, isHighlighted: false))
    }
    
    return segments
  }
}
