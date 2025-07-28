//
//  ContextView.swift
//  ClaudeCodeUI
//
//  Created on 12/27/24.
//

import SwiftUI
import XcodeObserverServiceInterface
import Combine

struct ContextView: View {
  @State var contextManager: ContextManager
  @State private var isExpanded = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Header
      HStack {
        Label(contextManager.contextSummary, systemImage: "doc.text.magnifyingglass")
          .font(.caption)
          .foregroundColor(.secondary)
        
        Spacer()
        
        // Toggle expand/collapse
        Button(action: {
          withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
          }
        }) {
          Image(systemName: isExpanded ? "chevron.up.circle" : "chevron.down.circle")
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
        
        // Clear all button
        if contextManager.hasContext {
          Button(action: {
            contextManager.clearAll()
          }) {
            Image(systemName: "xmark.circle.fill")
              .foregroundColor(.secondary)
          }
          .buttonStyle(.plain)
          .help("Clear all context")
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 6)
      .background(Color(NSColor.controlBackgroundColor))
      .cornerRadius(6)
      
      // Expanded content
      if isExpanded && contextManager.hasContext {
        VStack(alignment: .leading, spacing: 8) {
          // Workspace info
          if let workspace = contextManager.context.workspace {
            HStack {
              Image(systemName: "folder")
                .foregroundColor(.blue)
              Text(workspace)
                .font(.caption)
              Spacer()
            }
            .padding(.horizontal, 12)
          }
          
          
          // Active files
          if !contextManager.context.activeFiles.isEmpty {
            VStack(alignment: .leading, spacing: 4) {
              Text("Files")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
              
              ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                  ForEach(contextManager.context.activeFiles) { file in
                    ActiveFileView(
                      model: FileDisplayModel(
                        fileName: file.name,
                        filePath: file.path,
                        lineRange: nil,
                        isRemovable: true
                      ),
                      onRemove: {
                        contextManager.removeFile(id: file.id)
                      },
                      isPinned: contextManager.isPinnedActiveFile && contextManager.context.activeFiles.first?.id == file.id,
                      onTogglePin: {
                        contextManager.togglePinActiveFile()
                      }
                    )
                  }
                }
                .padding(.horizontal, 12)
              }
            }
          }
        }
        .padding(.vertical, 4)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        .cornerRadius(6)
      }
    }
    .animation(.easeInOut(duration: 0.2), value: contextManager.hasContext)
  }
}

// SelectionRow and FileRow are no longer needed as we're using ActiveFileView
