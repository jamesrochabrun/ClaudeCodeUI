//
//  MCPConfigurationView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI

struct MCPConfigurationView: View {
  @Binding var isPresented: Bool
  let settingsStorage: SettingsStorage
  @StateObject private var configManager = MCPConfigurationManager()
  @State private var selectedServer: MCPServerConfig?
  @State private var showingAddServer = false
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Form {
          Section("MCP Servers") {
            if configManager.configuration.mcpServers.isEmpty {
              HStack {
                Image(systemName: "server.rack")
                  .foregroundColor(.secondary)
                Text("No MCP servers configured")
                  .foregroundColor(.secondary)
              }
              .frame(maxWidth: .infinity)
              .padding(.vertical, 20)
            } else {
              ForEach(Array(configManager.configuration.mcpServers.keys), id: \.self) { serverName in
                if let server = configManager.configuration.mcpServers[serverName] {
                  MCPServerRow(server: server) {
                    print("[MCP] Edit button tapped for server: \(server.name)")
                    print("[MCP] Server details - command: \(server.command), args: \(server.args)")
                    selectedServer = server
                  }
                  .contextMenu {
                    Button("Edit") {
                      selectedServer = server
                    }
                    Button("Delete", role: .destructive) {
                      configManager.removeServer(named: server.name)
                    }
                  }
                }
              }
            }
            
            Button(action: { showingAddServer = true }) {
              Label("Add Server", systemImage: "plus.circle.fill")
            }
          }
          
          Section("Quick Add") {
            ForEach(MCPServerConfig.predefinedServers, id: \.name) { server in
              HStack {
                VStack(alignment: .leading) {
                  Text(server.name)
                    .font(.headline)
                  Text("\(server.command) \(server.args.joined(separator: " "))")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: {
                  if configManager.configuration.mcpServers[server.name] != nil {
                    // Remove server
                    print("[MCP] Quick Add: Removing server \(server.name)")
                    configManager.removeServer(named: server.name)
                  } else {
                    // Add server
                    print("[MCP] Quick Add: Adding server \(server.name)")
                    configManager.addServer(server)
                  }
                  // Automatically use the configuration after any change
                  if let path = configManager.getConfigurationPath() {
                    print("[MCP] Auto-setting config path after Quick Add: \(path)")
                    settingsStorage.setMcpConfigPath(path)
                  }
                }) {
                  Image(systemName: configManager.configuration.mcpServers[server.name] != nil ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(configManager.configuration.mcpServers[server.name] != nil ? .green : .secondary)
                    .font(.title2)
                }
                .buttonStyle(.plain)
              }
              .padding(.vertical, 4)
            }
          }
          
          Section("Configuration") {
            VStack(alignment: .leading, spacing: 12) {
              HStack {
                Text("Config File Location")
                Spacer()
                if let path = configManager.getConfigurationPath() {
                  Text(URL(fileURLWithPath: path).lastPathComponent)
                    .foregroundColor(.secondary)
                }
              }
              
              if let path = configManager.getConfigurationPath() {
                Text(path)
                  .font(.caption)
                  .foregroundColor(.secondary)
                  .textSelection(.enabled)
              }
              
              HStack {
                Button("Use This Configuration") {
                  copyToHomeAndUse()
                }
                .disabled(configManager.configuration.mcpServers.isEmpty)
                
                Button("Select File...") {
                  selectMcpConfigFile()
                }
              }
              
              Text("Note: Due to a bug with spaces in paths, the config will be copied to ~/.config/claude/mcp-config.json")
                .font(.caption)
                .foregroundColor(.orange)
            }
          }
          
          Section(header: Text("Notes")) {
            Text("• MCP tools must be explicitly allowed using allowedTools")
              .font(.caption)
            Text("• MCP tool names follow the pattern: mcp__<serverName>__<toolName>")
              .font(.caption)
            Text("• Use mcp__<serverName>__* to allow all tools from a server")
              .font(.caption)
          }
        }
        .formStyle(.grouped)
      }
      .navigationTitle("MCP Configuration")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            isPresented = false
          }
        }
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") {
            isPresented = false
          }
          .fontWeight(.semibold)
        }
      }
      .sheet(isPresented: $showingAddServer) {
        MCPServerEditView(
          server: MCPServerConfig(name: "", command: "npx", args: []),
          isNew: true
        ) { server in
          configManager.addServer(server)
        }
      }
      .sheet(item: $selectedServer) { server in
        MCPServerEditView(server: server, isNew: false) { updatedServer in
          configManager.updateServer(updatedServer)
          selectedServer = nil
        }
        .onAppear {
          print("[MCP] Edit sheet appeared for server: \(server.name)")
        }
      }
    }
    .frame(width: 600, height: 550)
  }
  
  private func copyToHomeAndUse() {
    let homeURL = FileManager.default.homeDirectoryForCurrentUser
    let configDir = homeURL.appendingPathComponent(".config/claude")
    let targetURL = configDir.appendingPathComponent("mcp-config.json")
    
    do {
      // Create .config/claude directory if it doesn't exist
      try FileManager.default.createDirectory(at: configDir, withIntermediateDirectories: true)
      
      // Export configuration to the new location
      try configManager.exportConfiguration(to: targetURL)
      
      // Update settings to use the new path
      settingsStorage.setMcpConfigPath(targetURL.path)
      
      print("[MCP] Configuration copied to: \(targetURL.path)")
      
      // Close the sheet
      isPresented = false
    } catch {
      print("[MCP] Failed to copy configuration: \(error)")
      // Show error alert
      let alert = NSAlert()
      alert.messageText = "Copy Failed"
      alert.informativeText = "Failed to copy configuration: \(error.localizedDescription)"
      alert.alertStyle = .warning
      alert.addButton(withTitle: "OK")
      alert.runModal()
    }
  }
  
  private func selectMcpConfigFile() {
    let panel = NSOpenPanel()
    panel.title = "Select MCP Configuration File"
    panel.message = "Choose a JSON file containing MCP server configurations"
    panel.prompt = "Select"
    panel.allowsMultipleSelection = false
    panel.canChooseFiles = true
    panel.canChooseDirectories = false
    panel.allowedFileTypes = ["json"]
    
    if panel.runModal() == .OK, let url = panel.url {
      settingsStorage.setMcpConfigPath(url.path)
      isPresented = false
    }
  }
}

struct MCPServerRow: View {
  let server: MCPServerConfig
  let onEdit: () -> Void
  
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(server.name)
          .font(.headline)
        Text("\(server.command) \(server.args.joined(separator: " "))")
          .font(.caption)
          .foregroundColor(.secondary)
          .lineLimit(1)
        if let env = server.env, !env.isEmpty {
          Text("Environment: \(env.keys.joined(separator: ", "))")
            .font(.caption2)
            .foregroundColor(.secondary)
        }
      }
      Spacer()
      Button(action: onEdit) {
        Image(systemName: "pencil.circle")
          .foregroundColor(.accentColor)
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 4)
  }
}

#Preview {
  let dependencyContainer = DependencyContainer()
  return MCPConfigurationView(isPresented: .constant(true), settingsStorage: dependencyContainer.settingsStorage)
}
