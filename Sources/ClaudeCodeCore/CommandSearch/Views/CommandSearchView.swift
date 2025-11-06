//
//  CommandSearchView.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 2025-11-05.
//

import SwiftUI

/// Displays inline command search results for / mentions
public struct CommandSearchView: View {
  @Bindable public var viewModel: CommandSearchViewModel
  public let onSelect: (CommandResult) -> Void
  public let onDismiss: () -> Void

  @State private var hoveredIndex: Int? = nil

  // MARK: - Computed Properties

  private var shouldShowEmptyState: Bool {
    viewModel.searchResults.isEmpty &&
    !viewModel.searchQuery.isEmpty &&
    !viewModel.isSearching
  }

  // MARK: - Initialization

  public init(
    viewModel: CommandSearchViewModel,
    onSelect: @escaping (CommandResult) -> Void,
    onDismiss: @escaping () -> Void
  ) {
    self.viewModel = viewModel
    self.onSelect = onSelect
    self.onDismiss = onDismiss
  }

  // MARK: - Body

  public var body: some View {
    VStack(spacing: 0) {
      headerBar
      Divider()
      resultsArea
    }
    .background(Color(NSColor.controlBackgroundColor))
  }

  // MARK: - Subviews

  private var headerBar: some View {
    CommandHeaderBar(
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

  private func resultRow(for result: CommandResult, at index: Int) -> some View {
    CommandSearchResultRow(
      result: result,
      isSelected: index == viewModel.selectedIndex,
      isHovered: index == hoveredIndex
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

      Text("No commands found for '/\(viewModel.searchQuery)'")
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

// MARK: - Command Search Result Row

private struct CommandSearchResultRow: View {
  let result: CommandResult
  let isSelected: Bool
  let isHovered: Bool

  @Environment(\.colorScheme) private var colorScheme

  private var backgroundColor: Color {
    if isSelected {
      return Color.brandPrimary.opacity(0.15)
    } else if isHovered {
      return Color.gray.opacity(0.1)
    }
    return Color.clear
  }

  var body: some View {
    HStack(spacing: 12) {
      commandIconView
      commandInfoView
      Spacer()
      scopeBadge
      selectionIndicator
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(backgroundColor)
    .contentShape(Rectangle())
  }

  // MARK: - Subviews

  private var commandIconView: some View {
    Image(systemName: "terminal")
      .font(.body)
      .foregroundColor(.brandPrimary)
      .frame(width: 20)
  }

  private var commandInfoView: some View {
    VStack(alignment: .leading, spacing: 2) {
      Text(result.displayName)
        .font(.body)
        .fontWeight(.medium)
        .foregroundColor(.primary)

      if let argumentHint = result.argumentHint {
        Text(argumentHint)
          .font(.caption)
          .foregroundColor(.secondary)
      } else if let description = result.description {
        Text(description)
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
    }
  }

  private var scopeBadge: some View {
    HStack(spacing: 4) {
      Image(systemName: result.scopeIcon)
        .font(.caption2)
      Text(result.scopeLabel)
        .font(.caption2)
    }
    .padding(.horizontal, 6)
    .padding(.vertical, 2)
    .background(Color.brandSecondary.opacity(0.2))
    .cornerRadius(4)
    .foregroundColor(.brandSecondary)
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

// MARK: - Command Header Bar Component

private struct CommandHeaderBar: View {
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
    Label("Searching for: /\(searchQuery)", systemImage: "magnifyingglass")
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
