//
//  EnhancedDiffView.swift
//  ClaudeCodeUI
//
//  Created on 1/30/2025.
//

import SwiftUI

/// Enhanced diff view with interactive apply/reject controls and collapsible sections
public struct EnhancedDiffView: View {
  @ObservedObject var viewModel: FileDiffViewModel
  @State private var collapsedSections: Set<Int> = []
  @State private var hoveredSection: Int?
  @State private var showApplyConfirmation = false
  @Environment(\.colorScheme) private var colorScheme
  
  private enum DiffViewMode: String, CaseIterable {
    case inline = "Inline"
    case split = "Split"
    
    var icon: String {
      switch self {
      case .inline:
        return "text.alignleft"
      case .split:
        return "rectangle.split.2x1"
      }
    }
  }
  
  @State private var viewMode: DiffViewMode = .inline
  
  public init(viewModel: FileDiffViewModel) {
    self.viewModel = viewModel
  }
  
  public var body: some View {
    VStack(spacing: 0) {
      // Header
      diffHeader
      
      // Content
      if viewModel.isLoading {
        loadingView
      } else if let error = viewModel.error {
        errorView(error: error)
      } else if let formattedDiff = viewModel.formattedDiff {
        ScrollView {
          VStack(spacing: 0) {
            ForEach(groupedChanges(from: formattedDiff), id: \.id) { section in
              DiffSectionView(
                section: section,
                isCollapsed: collapsedSections.contains(section.id),
                isHovered: hoveredSection == section.id,
                onToggleCollapse: { toggleSection(section.id) },
                onHover: { hoveredSection = $0 ? section.id : nil },
                onApply: { applySection(section) },
                onReject: { rejectSection(section) }
              )
            }
          }
        }
        .background(colorScheme.xcodeEditorBackground)
      } else {
        emptyView
      }
    }
    .confirmationDialog(
      "Apply Changes?",
      isPresented: $showApplyConfirmation,
      titleVisibility: .visible
    ) {
      Button("Apply All Changes") {
        Task {
          try? await viewModel.handleApplyAllChanges()
        }
      }
      Button("Apply Selected Sections") {
        Task {
          try? await viewModel.handleApplySelectedSections()
        }
      }
      .disabled(viewModel.selectedSections.isEmpty)
      
      Button("Cancel", role: .cancel) {}
    } message: {
      Text("This will modify the file at \(viewModel.filePath)")
    }
  }
  
  // MARK: - Views
  
  private var diffHeader: some View {
    HStack {
      // File info
      Label(URL(fileURLWithPath: viewModel.filePath).lastPathComponent, systemImage: "doc.text")
        .font(.system(.body, design: .monospaced))
      
      // Statistics
      if let stats = calculateStatistics() {
        HStack(spacing: 8) {
          Text("+\(stats.additions)")
            .foregroundColor(.green)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
          
          Text("-\(stats.deletions)")
            .foregroundColor(.red)
            .font(.system(size: 12, weight: .medium, design: .monospaced))
        }
        .padding(.horizontal, 8)
      }
      
      // Baseline drift indicator
      if viewModel.checkBaselineDrift() {
        Label("Baseline Drift", systemImage: "exclamationmark.triangle.fill")
          .foregroundColor(.orange)
          .font(.caption)
      }
      
      Spacer()
      
      // Actions
      Button(action: { showApplyConfirmation = true }) {
        Label("Apply", systemImage: "checkmark.circle.fill")
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.small)
      
      // View mode toggle
      Picker("View Mode", selection: $viewMode) {
        ForEach(DiffViewMode.allCases, id: \.self) { mode in
          Label(mode.rawValue, systemImage: mode.icon)
            .tag(mode)
        }
      }
      .pickerStyle(.segmented)
      .fixedSize()
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 8)
    .background(Color.gray.opacity(0.1))
  }
  
  private var loadingView: some View {
    VStack {
      ProgressView()
      Text("Generating diff...")
        .font(.caption)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 200)
  }
  
  private func errorView(error: String) -> some View {
    VStack(spacing: 12) {
      Image(systemName: "exclamationmark.triangle")
        .font(.largeTitle)
        .foregroundStyle(.red)
      Text("Error generating diff")
        .font(.headline)
      Text(error)
        .font(.caption)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
      
      Button("Retry") {
        Task {
          await viewModel.generateDiff()
        }
      }
      .buttonStyle(.bordered)
    }
    .padding()
    .frame(maxWidth: .infinity)
  }
  
  private var emptyView: some View {
    VStack {
      Image(systemName: "doc.text.magnifyingglass")
        .font(.largeTitle)
        .foregroundStyle(.secondary)
      Text("No changes to display")
        .font(.headline)
        .foregroundStyle(.secondary)
    }
    .frame(maxWidth: .infinity, minHeight: 200)
  }
  
  // MARK: - Helpers
  
  private func groupedChanges(from diff: FormattedFileChange) -> [DiffSection] {
    var sections: [DiffSection] = []
    var currentSection: DiffSection?
    
    for change in diff.changes {
      if change.change.type == .unchanged {
        // End current section if exists
        if let section = currentSection {
          sections.append(section)
          currentSection = nil
        }
        
        // Create unchanged section
        if let lastSection = sections.last,
           lastSection.type == .unchanged,
           lastSection.changes.count < 3 {
          // Merge small unchanged sections
          var updatedSection = lastSection
          updatedSection.changes.append(change)
          sections[sections.count - 1] = updatedSection
        } else {
          sections.append(DiffSection(
            id: sections.count,
            type: .unchanged,
            changes: [change],
            startLine: change.change.newLineNumber ?? 0,
            endLine: change.change.newLineNumber ?? 0
          ))
        }
      } else {
        // Continue or start changed section
        if currentSection == nil {
          currentSection = DiffSection(
            id: sections.count,
            type: .changed,
            changes: [],
            startLine: change.change.newLineNumber ?? change.change.oldLineNumber ?? 0,
            endLine: 0
          )
        }
        currentSection?.changes.append(change)
        currentSection?.endLine = change.change.newLineNumber ?? change.change.oldLineNumber ?? 0
      }
    }
    
    // Add final section
    if let section = currentSection {
      sections.append(section)
    }
    
    return sections
  }
  
  private func calculateStatistics() -> (additions: Int, deletions: Int)? {
    guard let diff = viewModel.formattedDiff else { return nil }
    let additions = diff.changes.filter { $0.change.type == .added }.count
    let deletions = diff.changes.filter { $0.change.type == .removed }.count
    return (additions, deletions)
  }
  
  private func toggleSection(_ id: Int) {
    if collapsedSections.contains(id) {
      collapsedSections.remove(id)
    } else {
      collapsedSections.insert(id)
    }
  }
  
  private func applySection(_ section: DiffSection) {
    viewModel.selectedSections.insert("\(section.id)")
  }
  
  private func rejectSection(_ section: DiffSection) {
    viewModel.selectedSections.remove("\(section.id)")
  }
}

// MARK: - Supporting Types

struct DiffSection {
  let id: Int
  let type: SectionType
  var changes: [FormattedLineChange]
  var startLine: Int
  var endLine: Int
  
  enum SectionType {
    case changed
    case unchanged
  }
}

struct DiffSectionView: View {
  let section: DiffSection
  let isCollapsed: Bool
  let isHovered: Bool
  let onToggleCollapse: () -> Void
  let onHover: (Bool) -> Void
  let onApply: () -> Void
  let onReject: () -> Void
  
  @Environment(\.colorScheme) private var colorScheme
  
  var body: some View {
    VStack(spacing: 0) {
      // Section header for unchanged code
      if section.type == .unchanged && section.changes.count > 3 {
        HStack {
          Button(action: onToggleCollapse) {
            HStack(spacing: 4) {
              Image(systemName: isCollapsed ? "chevron.right" : "chevron.down")
                .font(.caption)
              Text("\(section.changes.count) unchanged lines")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
          }
          .buttonStyle(.plain)
          
          Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 4)
        .background(Color.gray.opacity(0.05))
      }
      
      // Content
      if !isCollapsed {
        ForEach(Array(section.changes.enumerated()), id: \.offset) { _, change in
          HStack(spacing: 0) {
            // Line numbers
            HStack(spacing: 0) {
              Text(change.change.oldLineNumber.map { String($0) } ?? "")
                .frame(width: 40, alignment: .trailing)
                .foregroundStyle(.secondary)
              
              Text(change.change.newLineNumber.map { String($0) } ?? "")
                .frame(width: 40, alignment: .trailing)
                .foregroundStyle(.secondary)
            }
            .font(.system(size: 11, design: .monospaced))
            .padding(.horizontal, 4)
            
            // Diff indicator
            Text(diffIndicator(for: change.change.type))
              .frame(width: 20)
              .font(.system(size: 12, design: .monospaced))
              .foregroundColor(diffColor(for: change.change.type))
            
            // Content
            Text(change.formattedContent)
              .font(.system(size: 12, design: .monospaced))
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(.vertical, 1)
            
            // Hover actions for changed sections
            if section.type == .changed && isHovered {
              HStack(spacing: 4) {
                Button(action: onApply) {
                  Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                
                Button(action: onReject) {
                  Image(systemName: "xmark.circle.fill")
                    .foregroundColor(.red)
                }
                .buttonStyle(.plain)
              }
              .padding(.horizontal, 8)
            }
          }
          .background(diffBackground(for: change.change.type))
        }
      }
    }
    .onHover { hovering in
      if section.type == .changed {
        onHover(hovering)
      }
    }
  }
  
  private func diffIndicator(for type: DiffContentType) -> String {
    switch type {
    case .added: return "+"
    case .removed: return "-"
    case .unchanged: return " "
    }
  }
  
  private func diffColor(for type: DiffContentType) -> Color {
    switch type {
    case .added: return .green
    case .removed: return .red
    case .unchanged: return .secondary
    }
  }
  
  private func diffBackground(for type: DiffContentType) -> Color {
    switch type {
    case .added: return Color.green.opacity(0.1)
    case .removed: return Color.red.opacity(0.1)
    case .unchanged: return Color.clear
    }
  }
}

// MARK: - Color Scheme Extension

extension ColorScheme {
  var xcodeEditorBackground: Color {
    self == .dark ? Color(white: 0.11) : Color(white: 0.98)
  }
}