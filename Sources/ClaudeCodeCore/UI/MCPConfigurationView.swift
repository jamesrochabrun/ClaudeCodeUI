//
//  MCPConfigurationView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI
import CCCustomPermissionServiceInterface

struct MCPConfigurationView: View {
  // MARK: - Properties
  @Binding var isPresented: Bool
  let mcpConfigStorage: MCPConfigStorage
  let globalPreferences: GlobalPreferencesStorage?
  let uiConfiguration: UIConfiguration
  @State private var configManager = MCPConfigurationManager()
  // Removed selectedServer and showingAddServer as editing is now done via JSON editor
  @State private var showingJSONEditor = false
  @State private var oldConfiguration: MCPConfiguration = MCPConfiguration()
  
  // MARK: - Body
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Form {
          serversSection
          quickAddSection
          configurationSection
          
          // Custom permission section (only show if globalPreferences is available)
          if globalPreferences != nil {
            customPermissionSection
          }
          
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
      .sheet(isPresented: $showingJSONEditor) {
        MCPConfigEditorView(
          isPresented: $showingJSONEditor,
          configManager: configManager
        )
        .onAppear {
          // Capture the configuration before editing
          oldConfiguration = configManager.configuration
        }
        .onDisappear {
          // Compare old and new configuration
          let oldServers = Set(oldConfiguration.mcpServers.keys)
          let newServers = Set(configManager.configuration.mcpServers.keys)
          let removedServers = oldServers.subtracting(newServers)
          
          // Clean up removed servers
          for server in removedServers {
            MCPToolsDiscoveryService.shared.removeToolsForServer(server)
            // Also remove from global preferences if available
            if let preferences = globalPreferences {
              preferences.selectedMCPTools.removeValue(forKey: server)
              // Remove from stored server tools as well
              preferences.mcpServerTools.removeValue(forKey: server)
            }
          }
          
          // Reload configuration when editor closes
          configManager.loadConfiguration()
        }
      }
      // Editing is now done through the JSON editor
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
      
      Button(action: { 
        // Capture current configuration before editing
        oldConfiguration = configManager.configuration
        showingJSONEditor = true 
      }) {
        Label("Edit Configuration File", systemImage: "doc.text.badge.plus")
      }
      .help("Open the JSON configuration file for direct editing")
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
        MCPServerRow(server: server)
        .contextMenu {
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
      Button("Edit JSON") {
        // Capture current configuration before editing
        oldConfiguration = configManager.configuration
        showingJSONEditor = true
      }
      .help("Edit the configuration file directly as JSON")
      
      Button("Select File...") {
        selectMcpConfigFile()
      }
    }
  }
  
  private var configurationWarningView: some View {
    Text("Configuration is stored at ~/.config/claude/mcp-config.json")
      .font(.caption)
      .foregroundColor(.secondary)
  }
  
  private var customPermissionSection: some View {
    Section("Custom Permission Settings") {
      if let preferences = globalPreferences {
        VStack(alignment: .leading, spacing: 12) {
          // Auto-approve settings
          VStack(alignment: .leading, spacing: 8) {
            if uiConfiguration.showRiskData {
              Toggle("Auto-approve low-risk operations", isOn: Binding(
                get: { preferences.autoApproveLowRisk },
                set: { preferences.autoApproveLowRisk = $0 }
              ))
              .help("Automatically approve operations classified as low-risk (e.g., reading files)")
            }
          }
          
          Divider()
          
          // Display settings
          Toggle("Show detailed permission information", isOn: Binding(
            get: { preferences.showDetailedPermissionInfo },
            set: { preferences.showDetailedPermissionInfo = $0 }
          ))
          .help("Show detailed information about tools and their parameters in permission prompts")
          
          Divider()
          
          // Timeout and limits
          VStack(alignment: .leading, spacing: 8) {
            Toggle("Enable timeout for permission requests", isOn: Binding(
              get: { preferences.permissionTimeoutEnabled },
              set: { preferences.permissionTimeoutEnabled = $0 }
            ))
            .help("When disabled, permission requests will wait indefinitely for user response")
            
            if preferences.permissionTimeoutEnabled {
              HStack {
                Text("Timeout duration:")
                Spacer()
                TextField("Seconds", value: Binding(
                  get: { Int(preferences.permissionRequestTimeout) },
                  set: { preferences.permissionRequestTimeout = TimeInterval($0) }
                ), format: .number)
                .textFieldStyle(.roundedBorder)
                .frame(width: 80)
                Text("seconds")
                  .foregroundColor(.secondary)
              }
              .padding(.leading, 20)
              .help("How long to wait for user response before timing out permission requests")
            }
            
            HStack {
              Text("Max concurrent requests:")
              Spacer()
              TextField("Count", value: Binding(
                get: { preferences.maxConcurrentPermissionRequests },
                set: { preferences.maxConcurrentPermissionRequests = $0 }
              ), format: .number)
              .textFieldStyle(.roundedBorder)
              .frame(width: 80)
            }
            .help("Maximum number of simultaneous permission requests allowed")
          }
          
          // Permission system status
          Divider()
          
          HStack {
            Image(systemName: "checkmark.shield.fill")
              .foregroundColor(.green)
            Text("Custom permission system is active")
              .font(.caption)
              .foregroundColor(.secondary)
            Spacer()
          }
        }
      }
    }
  }
  
  private var notesSection: some View {
    Section(header: Text("Notes")) {
      VStack(alignment: .leading, spacing: 4) {
        noteItem("MCP tools must be explicitly allowed using allowedTools")
        noteItem("MCP tool names follow the pattern: mcp__<serverName>__<toolName>")
        noteItem("Use mcp__<serverName>__* to allow all tools from a server")
        noteItem("Custom permission prompts will appear for non-whitelisted tools")
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
    // Set the config path to Claude's default location
    let homeURL = FileManager.default.homeDirectoryForCurrentUser
    let configPath = homeURL
      .appendingPathComponent(".config/claude/mcp-config.json")
      .path
    mcpConfigStorage.setMcpConfigPath(configPath)
    print("[MCP] Configuration path set to: \(configPath)")
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
  
  return MCPConfigurationView(
    isPresented: .constant(true),
    mcpConfigStorage: PreviewMCPStorage(),
    globalPreferences: nil,
    uiConfiguration: .default
  )
}
