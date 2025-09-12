//
//  ToolsSelectionView.swift
//  ClaudeCodeUI
//
//  Created on 12/6/2025.
//

import SwiftUI

struct ToolsSelectionView: View {
  @Environment(\.dismiss) private var dismiss
  @Binding var selectedTools: Set<String>
  @Binding var selectedMCPTools: [String: Set<String>]
  let availableToolsByServer: [String: [String]]
  
  @State private var expandedSections: Set<String> = []
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        List {
          // Iterate through each server and its tools
          ForEach(Array(availableToolsByServer.keys.sorted()), id: \.self) { serverName in
            Section {
              ForEach(availableToolsByServer[serverName] ?? [], id: \.self) { tool in
                HStack {
                  Text(tool)
                    .font(.system(.body, design: .monospaced))
                  Spacer()
                  if isToolSelected(tool, server: serverName) {
                    Image(systemName: "checkmark.circle.fill")
                      .foregroundColor(.accentColor)
                  } else {
                    Image(systemName: "circle")
                      .foregroundColor(.secondary)
                  }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                  toggleToolSelection(tool, server: serverName)
                }
              }
            } header: {
              HStack {
                Text(serverName)
                  .font(.system(.subheadline, design: .monospaced))
                  .fontWeight(.semibold)
                Spacer()
                if let tools = availableToolsByServer[serverName] {
                  Text("\(selectedCount(for: serverName))/\(tools.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
              }
            }
          }
        }
        .listStyle(.inset)
        
        Divider()
        
        HStack {
          Button("Select All") {
            selectAll()
          }
          .buttonStyle(.bordered)
          
          Button("Clear All") {
            clearAll()
          }
          .buttonStyle(.bordered)
          
          Spacer()
          
          Button("Cancel") {
            dismiss()
          }
          .buttonStyle(.bordered)
          
          Button("Save") {
            dismiss()
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
        }
        .padding()
      }
      .navigationTitle("Select Tools")
      .frame(width: 500, height: 600)
    }
  }
  
  // MARK: - Helper Methods
  
  private func isToolSelected(_ tool: String, server: String) -> Bool {
    if server == "Claude Code" {
      return selectedTools.contains(tool)
    } else {
      return selectedMCPTools[server]?.contains(tool) ?? false
    }
  }
  
  private func toggleToolSelection(_ tool: String, server: String) {
    if server == "Claude Code" {
      if selectedTools.contains(tool) {
        selectedTools.remove(tool)
      } else {
        selectedTools.insert(tool)
      }
    } else {
      var serverTools = selectedMCPTools[server] ?? Set<String>()
      if serverTools.contains(tool) {
        serverTools.remove(tool)
      } else {
        serverTools.insert(tool)
      }
      selectedMCPTools[server] = serverTools
    }
  }
  
  private func selectedCount(for server: String) -> Int {
    if server == "Claude Code" {
      let serverTools = availableToolsByServer[server] ?? []
      return serverTools.filter { selectedTools.contains($0) }.count
    } else {
      return selectedMCPTools[server]?.count ?? 0
    }
  }
  
  private func selectAll() {
    for (server, tools) in availableToolsByServer {
      if server == "Claude Code" {
        selectedTools.formUnion(tools)
      } else {
        selectedMCPTools[server] = Set(tools)
      }
    }
  }
  
  private func clearAll() {
    selectedTools.removeAll()
    selectedMCPTools.removeAll()
  }
}

#Preview {
  ToolsSelectionView(
    selectedTools: .constant(Set(["Bash", "ls", "Read"])),
    selectedMCPTools: .constant(["github": Set(["create_issue", "list_issues"])]),
    availableToolsByServer: [
      "Claude Code": ["Bash", "ls", "Read", "WebFetch", "Glob", "Grep", "Edit", "MultiEdit", "Write"],
      "github": ["create_issue", "list_issues", "create_pr", "merge_pr"],
      "approval_server": ["approval_prompt"]
    ])
}
