//
//  MCPServerEditView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI

struct MCPServerEditView: View {
  @State private var name: String
  @State private var command: String
  @State private var argsText: String
  @State private var envPairs: [EnvironmentPair]
  
  let isNew: Bool
  let onSave: (MCPServerConfig) -> Void
  @Environment(\.dismiss) private var dismiss
  
  init(server: MCPServerConfig, isNew: Bool, onSave: @escaping (MCPServerConfig) -> Void) {
    _name = State(initialValue: server.name)
    _command = State(initialValue: server.command)
    _argsText = State(initialValue: server.args.joined(separator: " "))
    _envPairs = State(initialValue: server.env?.map { EnvironmentPair(key: $0.key, value: $0.value) } ?? [])
    self.isNew = isNew
    self.onSave = onSave
  }
  
  var body: some View {
    NavigationStack {
      Form {
        Section("Server Details") {
          TextField("Name", text: $name)
            .disabled(!isNew)
          
          TextField("Command", text: $command)
            .help("The command to execute (e.g., npx, node)")
          
          VStack(alignment: .leading) {
            Text("Arguments")
              .font(.caption)
              .foregroundColor(.secondary)
            TextField("Arguments (space-separated)", text: $argsText)
              .help("Command arguments separated by spaces")
          }
        }
        
        Section("Environment Variables") {
          ForEach($envPairs) { $pair in
            HStack {
              TextField("Key", text: $pair.key)
                .frame(width: 150)
              TextField("Value", text: $pair.value)
              Button(action: {
                envPairs.removeAll { $0.id == pair.id }
              }) {
                Image(systemName: "minus.circle.fill")
                  .foregroundColor(.red)
              }
              .buttonStyle(.plain)
            }
          }
          
          Button(action: {
            envPairs.append(EnvironmentPair(key: "", value: ""))
          }) {
            Label("Add Variable", systemImage: "plus.circle.fill")
          }
        }
        
        Section("Preview") {
          VStack(alignment: .leading, spacing: 8) {
            Text("Command Preview")
              .font(.caption)
              .foregroundColor(.secondary)
            
            Text(commandPreview)
              .font(.system(.caption, design: .monospaced))
              .padding(8)
              .background(Color.gray.opacity(0.1))
              .cornerRadius(4)
              .textSelection(.enabled)
          }
        }
      }
      .navigationTitle(isNew ? "Add MCP Server" : "Edit MCP Server")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            dismiss()
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            save()
          }
          .disabled(name.isEmpty || command.isEmpty)
        }
      }
    }
    .frame(width: 900, height: 700)
  }
  
  private var commandPreview: String {
    var preview = command
    let args = argsText.split(separator: " ").map(String.init)
    if !args.isEmpty {
      preview += " " + args.joined(separator: " ")
    }
    return preview
  }
  
  private func save() {
    let args = argsText.split(separator: " ").map(String.init)
    let env = envPairs.reduce(into: [String: String]()) { result, pair in
      if !pair.key.isEmpty && !pair.value.isEmpty {
        result[pair.key] = pair.value
      }
    }
    
    let server = MCPServerConfig(
      name: name,
      command: command,
      args: args,
      env: env.isEmpty ? nil : env
    )
    
    onSave(server)
    dismiss()
  }
}

struct EnvironmentPair: Identifiable {
  let id = UUID()
  var key: String
  var value: String
}

#Preview {
  MCPServerEditView(
    server: MCPServerConfig(name: "test", command: "npx", args: ["-y", "test"]),
    isNew: true
  ) { _ in }
}
