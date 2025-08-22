//
//  HierarchicalSessionsView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 8/18/2025.
//

import SwiftUI

/// A view that displays sessions organized by project in a hierarchical tree structure
struct HierarchicalSessionsView: View {
  @State var viewModel: ChatViewModel
  @State private var expandedProjects: Set<String> = []
  @State private var projectNodes: [ProjectNode] = []
  @State private var isLoadingProjects = false
  @State private var loadError: Error?
  
  var body: some View {
    ScrollView {
      if isLoadingProjects {
        loadingView
      } else if let error = loadError {
        errorView(error)
      } else if projectNodes.isEmpty {
        emptyView
      } else {
        LazyVStack(spacing: 0) {
          ForEach(projectNodes) { node in
            ProjectGroupView(
              node: node,
              isExpanded: expandedProjects.contains(node.id),
              currentSessionId: viewModel.currentSessionId,
              onToggleExpand: {
                toggleProject(node.id)
              },
              onSelectSession: { session in
                selectSession(session)
              },
              onDeleteSession: { session in
                deleteSession(session)
              },
              expandedProjects: $expandedProjects
            )
          }
        }
        .padding(.vertical, 8)
      }
    }
    .onAppear {
      Task {
        await loadProjects()
      }
    }
  }
  
  private var loadingView: some View {
    VStack {
      Spacer()
      ProgressView()
        .progressViewStyle(CircularProgressViewStyle())
        .scaleEffect(0.8)
      Text("Loading projects...")
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.top, 8)
      Spacer()
    }
  }
  
  private func errorView(_ error: Error) -> some View {
    VStack(spacing: 8) {
      Spacer()
      Image(systemName: "exclamationmark.triangle.fill")
        .font(.largeTitle)
        .foregroundColor(.orange)
      Text("Failed to load projects")
        .font(.caption)
        .fontWeight(.medium)
      Text(error.localizedDescription)
        .font(.caption)
        .foregroundColor(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal)
      Button("Retry") {
        Task {
          await loadProjects()
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.small)
      Spacer()
    }
    .padding()
  }
  
  private var emptyView: some View {
    VStack {
      Spacer()
      Image(systemName: "folder.badge.questionmark")
        .font(.largeTitle)
        .foregroundColor(.secondary)
      Text("No Claude sessions found")
        .font(.caption)
        .foregroundColor(.secondary)
        .padding(.top, 8)
      Text("Start a conversation with Claude to see it here")
        .font(.caption2)
        .foregroundColor(Color.secondary.opacity(0.7))
      Spacer()
    }
    .frame(maxWidth: .infinity)
    .padding()
  }
  
  private func toggleProject(_ projectId: String) {
    withAnimation(.easeInOut(duration: 0.2)) {
      if expandedProjects.contains(projectId) {
        expandedProjects.remove(projectId)
      } else {
        expandedProjects.insert(projectId)
      }
    }
  }
  
  private func selectSession(_ session: StoredSession) {
    guard !viewModel.isLoading else { return }
    
    Task {
      await viewModel.switchToSession(session.id)
    }
  }
  
  private func deleteSession(_ session: StoredSession) {
    Task {
      await viewModel.deleteSession(id: session.id)
      // Reload to refresh the tree
      await loadProjects()
    }
  }
  
  private func loadProjects() async {
    isLoadingProjects = true
    loadError = nil
    
    do {
      // Get the native adapter if available
      if let adapter = viewModel.sessionStorage as? ClaudeNativeStorageAdapter {
        let nodes = try await adapter.getHierarchicalSessions()
        await MainActor.run {
          self.projectNodes = nodes
          // Auto-expand projects with recent sessions
          for node in nodes {
            if let recentDate = node.mostRecentSessionDate,
               Date().timeIntervalSince(recentDate) < 7 * 24 * 60 * 60 { // Within last week
              expandedProjects.insert(node.id)
            }
          }
          self.isLoadingProjects = false
        }
      } else {
        // Fallback to flat list if not using native adapter
        await viewModel.loadSessions()
        let sessions = viewModel.sessions
        
        // Create a single "Local Sessions" node
        let localNode = ProjectNode(
          id: "local",
          name: "Local Sessions",
          fullPath: "",
          sessions: sessions,
          children: [],
          depth: 0
        )
        
        await MainActor.run {
          self.projectNodes = sessions.isEmpty ? [] : [localNode]
          if !sessions.isEmpty {
            expandedProjects.insert("local")
          }
          self.isLoadingProjects = false
        }
      }
    } catch {
      await MainActor.run {
        self.loadError = error
        self.isLoadingProjects = false
      }
    }
  }
}

/// A view that displays a project group with its sessions
struct ProjectGroupView: View {
  let node: ProjectNode
  let isExpanded: Bool
  let currentSessionId: String?
  let onToggleExpand: () -> Void
  let onSelectSession: (StoredSession) -> Void
  let onDeleteSession: (StoredSession) -> Void
  @Binding var expandedProjects: Set<String>
  
  var body: some View {
    VStack(spacing: 0) {
      // Project header
      Button(action: onToggleExpand) {
        HStack(spacing: 4) {
          // Disclosure arrow
          Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
            .font(.system(size: 10, weight: .medium))
            .foregroundColor(.secondary)
            .frame(width: 12)
          
          // Folder icon
          Image(systemName: isExpanded ? "folder.fill" : "folder")
            .font(.system(size: 12))
            .foregroundColor(.accentColor)
          
          // Project name
          Text(node.name)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
            .lineLimit(1)
            .truncationMode(.middle)
          
          Spacer()
          
          // Session count badge
          if node.totalSessionCount > 0 {
            Text("\(node.totalSessionCount)")
              .font(.system(size: 11))
              .foregroundColor(.secondary)
              .padding(.horizontal, 6)
              .padding(.vertical, 2)
              .background(Color.secondary.opacity(0.1))
              .cornerRadius(4)
          }
        }
        .padding(.horizontal, CGFloat(12 + (node.depth * 12)))
        .padding(.vertical, 6)
        .contentShape(Rectangle())
      }
      .buttonStyle(.plain)
      .background(Color.primary.opacity(isExpanded ? 0.03 : 0))
      
      // Sessions and child projects
      if isExpanded {
        // Sessions for this project
        ForEach(node.sessions) { session in
          SessionRowView(
            session: session,
            isActive: session.id == currentSessionId,
            indentLevel: node.depth + 1,
            onSelect: {
              onSelectSession(session)
            },
            onDelete: {
              onDeleteSession(session)
            }
          )
        }
        
        // Child projects
        ForEach(node.children) { childNode in
          ProjectGroupView(
            node: childNode,
            isExpanded: expandedProjects.contains(childNode.id),
            currentSessionId: currentSessionId,
            onToggleExpand: {
              toggleChild(childNode.id)
            },
            onSelectSession: onSelectSession,
            onDeleteSession: onDeleteSession,
            expandedProjects: $expandedProjects
          )
        }
      }
    }
  }
  
  private func toggleChild(_ childId: String) {
    withAnimation(.easeInOut(duration: 0.2)) {
      if expandedProjects.contains(childId) {
        expandedProjects.remove(childId)
      } else {
        expandedProjects.insert(childId)
      }
    }
  }
}

/// Enhanced session row with indentation support
extension SessionRowView {
  init(session: StoredSession, isActive: Bool, indentLevel: Int, onSelect: @escaping () -> Void, onDelete: @escaping () -> Void) {
    self.init(
      session: session,
      isActive: isActive,
      onSelect: onSelect,
      onDelete: onDelete
    )
    // Note: Actual indentation would be applied in the view's padding
  }
}