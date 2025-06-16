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
  let availableTools: [String]
  let onSave: () -> Void
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        List {
          ForEach(availableTools, id: \.self) { tool in
            HStack {
              Text(tool)
                .font(.system(.body, design: .monospaced))
              Spacer()
              if selectedTools.contains(tool) {
                Image(systemName: "checkmark.circle.fill")
                  .foregroundColor(.accentColor)
              } else {
                Image(systemName: "circle")
                  .foregroundColor(.secondary)
              }
            }
            .contentShape(Rectangle())
            .onTapGesture {
              if selectedTools.contains(tool) {
                selectedTools.remove(tool)
              } else {
                selectedTools.insert(tool)
              }
            }
          }
        }
        .listStyle(.inset)
        
        Divider()
        
        HStack {
          Button("Select All") {
            selectedTools = Set(availableTools)
          }
          .buttonStyle(.bordered)
          
          Button("Clear All") {
            selectedTools.removeAll()
          }
          .buttonStyle(.bordered)
          
          Spacer()
          
          Button("Cancel") {
            dismiss()
          }
          .buttonStyle(.bordered)
          
          Button("Save") {
            onSave()
            dismiss()
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
        }
        .padding()
      }
      .navigationTitle("Select Tools")
      .frame(width: 400, height: 500)
    }
  }
}

#Preview {
  ToolsSelectionView(
    selectedTools: .constant(Set(["Bash", "LS", "Read"])),
    availableTools: ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write"],
    onSave: {}
  )
}