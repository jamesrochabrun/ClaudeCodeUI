//
//  MCPConfigurationView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI

struct MCPConfigurationView: View {
  // MARK: - Properties
  @Binding var isPresented: Bool
  let mcpConfigStorage: MCPConfigStorage
  @State private var configManager = MCPConfigurationManager()
  @State private var selectedServer: MCPServerConfig?
  @State private var showingAddServer = false
  
  // MARK: - Body
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Form {
          serversSection
          quickAddSection
          configurationSection
          notesSection
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
  
  // MARK: - View Components
  private var serversSection: some View {
    Section("MCP Servers") {
      if configManager.configuration.mcpServers.isEmpty {
        emptyServersView
      } else {
        configuredServersView
      }
      
      Button(action: { showingAddServer = true }) {
        Label("Add Server", systemImage: "plus.circle.fill")
      }
    }
  }
  
  private var emptyServersView: some View {
    HStack {
      Image(systemName: "server.rack")
        .foregroundColor(.secondary)
      Text("No MCP servers configured")
        .foregroundColor(.secondary)
    }
    .frame(maxWidth: .infinity)
    .padding(.vertical, 20)
  }
  
  private var configuredServersView: some View {
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
  
  private var quickAddSection: some View {
    Section("Quick Add") {
      ForEach(MCPServerConfig.predefinedServers, id: \.name) { server in
        QuickAddServerRow(
          server: server,
          isAdded: configManager.configuration.mcpServers[server.name] != nil,
          onToggle: { toggleQuickAddServer(server) }
        )
      }
    }
  }
  
  private var configurationSection: some View {
    Section("Configuration") {
      VStack(alignment: .leading, spacing: 12) {
        configFileLocationView
        configurationActionsView
        configurationWarningView
      }
    }
  }
  
  private var configFileLocationView: some View {
    VStack(alignment: .leading, spacing: 4) {
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
    }
  }
  
  private var configurationActionsView: some View {
    HStack {
      Button("Use This Configuration") {
        copyToHomeAndUse()
      }
      .disabled(configManager.configuration.mcpServers.isEmpty)
      
      Button("Select File...") {
        selectMcpConfigFile()
      }
    }
  }
  
  private var configurationWarningView: some View {
    Text("Note: Due to a bug with spaces in paths, the config will be copied to ~/.config/claude/mcp-config.json")
      .font(.caption)
      .foregroundColor(.orange)
  }
  
  private var notesSection: some View {
    Section(header: Text("Notes")) {
      VStack(alignment: .leading, spacing: 4) {
        noteItem("MCP tools must be explicitly allowed using allowedTools")
        noteItem("MCP tool names follow the pattern: mcp__<serverName>__<toolName>")
        noteItem("Use mcp__<serverName>__* to allow all tools from a server")
      }
    }
  }
  
  private func noteItem(_ text: String) -> some View {
    Text("• \(text)")
      .font(.caption)
  }
  
  // MARK: - Actions
  private func toggleQuickAddServer(_ server: MCPServerConfig) {
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
      mcpConfigStorage.setMcpConfigPath(path)
    }
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
      mcpConfigStorage.setMcpConfigPath(targetURL.path)
      
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
    panel.allowedContentTypes = [.json]
    
    if panel.runModal() == .OK, let url = panel.url {
      mcpConfigStorage.setMcpConfigPath(url.path)
      isPresented = false
    }
  }
}

// MARK: - Supporting Views
struct MCPServerRow: View {
  let server: MCPServerConfig
  let onEdit: () -> Void
  
  var body: some View {
    HStack {
      VStack(alignment: .leading, spacing: 4) {
        Text(server.name)
          .font(.headline)
        if let url = server.url {
          Text(url)
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
        } else {
          Text("\(server.command) \(server.args.joined(separator: " "))")
            .font(.caption)
            .foregroundColor(.secondary)
            .lineLimit(1)
        }
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

struct QuickAddServerRow: View {
  let server: MCPServerConfig
  let isAdded: Bool
  let onToggle: () -> Void
  
  var body: some View {
    HStack {
      VStack(alignment: .leading) {
        Text(server.name)
          .font(.headline)
        if let url = server.url {
          Text(url)
            .font(.caption)
            .foregroundColor(.secondary)
        } else {
          Text("\(server.command) \(server.args.joined(separator: " "))")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      Spacer()
      Button(action: onToggle) {
        Image(systemName: isAdded ? "checkmark.circle.fill" : "circle")
          .foregroundColor(isAdded ? .green : .secondary)
          .font(.title2)
      }
      .buttonStyle(.plain)
    }
    .padding(.vertical, 4)
  }
}

#Preview {
  struct PreviewMCPStorage: MCPConfigStorage {
    func setMcpConfigPath(_ path: String) {
      print("Preview: Setting MCP path to \(path)")
    }
  }
  
  return MCPConfigurationView(isPresented: .constant(true), mcpConfigStorage: PreviewMCPStorage())
}
