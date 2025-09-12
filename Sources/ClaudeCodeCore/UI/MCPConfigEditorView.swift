//
//  MCPConfigEditorView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 12/19/24.
//

import SwiftUI
import AppKit

struct MCPConfigEditorView: View {
  @Binding var isPresented: Bool
  let configManager: MCPConfigurationManager
  @State private var jsonText: String = ""
  @State private var showingError = false
  @State private var errorMessage = ""
  @State private var hasChanges = false
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        // File path header
        filePathHeader
        
        Divider()
        
        // JSON Editor
        ScrollView {
          TextEditor(text: $jsonText)
            .font(.system(.body, design: .monospaced))
            .padding(8)
            .onChange(of: jsonText) { _, _ in
              hasChanges = true
            }
        }
        .background(Color(NSColor.textBackgroundColor))
        
        Divider()
        
        // Action buttons
        actionButtons
      }
      .navigationTitle("Edit MCP Configuration")
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("Cancel") {
            if hasChanges {
              showUnsavedChangesAlert()
            } else {
              isPresented = false
            }
          }
        }
        
        ToolbarItem(placement: .confirmationAction) {
          Button("Save") {
            saveConfiguration()
          }
          .disabled(!hasChanges)
          .fontWeight(.semibold)
        }
      }
      .onAppear {
        loadConfiguration()
      }
      .alert("Error", isPresented: $showingError) {
        Button("OK") { }
      } message: {
        Text(errorMessage)
      }
    }
    .frame(width: 800, height: 600)
  }
  
  private var filePathHeader: some View {
    HStack {
      Image(systemName: "doc.text")
        .foregroundColor(.secondary)
      
      if let path = configManager.getConfigurationPath() {
        Text(path)
          .font(.system(.caption, design: .monospaced))
          .foregroundColor(.secondary)
          .textSelection(.enabled)
      } else {
        Text("No configuration file")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      
      Spacer()
      
      Button(action: openInExternalEditor) {
        Label("View File", systemImage: "arrow.up.forward.square")
      }
      .help("Open file in external editor with debug flags")
    }
    .padding(.horizontal)
    .padding(.vertical, 8)
    .background(Color(NSColor.controlBackgroundColor))
  }
  
  private var actionButtons: some View {
    HStack {
      // Status indicator
      if hasChanges {
        Label("Unsaved changes", systemImage: "pencil.circle.fill")
          .foregroundColor(.orange)
          .font(.caption)
      }
      
      Spacer()
      
      // Reload button
      Button(action: reloadFromFile) {
        Label("Reload", systemImage: "arrow.clockwise")
      }
      .help("Reload configuration from file (discards changes)")
      
      // Format JSON button
      Button(action: formatJSON) {
        Label("Format Now", systemImage: "text.alignleft")
      }
      .help("Format and indent JSON immediately")
    }
    .padding()
    .background(Color(NSColor.controlBackgroundColor))
  }
  
  private func loadConfiguration() {
    guard let path = configManager.getConfigurationPath(),
          let url = URL(string: "file://\(path)") else {
      // If no file exists, create a template
      createTemplateJSON()
      return
    }
    
    do {
      let data = try Data(contentsOf: url)
      if let jsonObject = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
        let formattedData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
        jsonText = String(data: formattedData, encoding: .utf8) ?? "{}"
        hasChanges = false
      }
    } catch {
      createTemplateJSON()
    }
  }
  
  private func createTemplateJSON() {
    let template = """
    {
      "mcpServers": {
        "example-server": {
          "command": "npx",
          "args": ["-y", "@modelcontextprotocol/server-example"],
          "env": {}
        }
      }
    }
    """
    jsonText = template
    hasChanges = false
  }
  
  private func saveConfiguration() {
    // Validate JSON first
    guard let data = jsonText.data(using: .utf8) else {
      showError("Invalid text encoding")
      return
    }
    
    do {
      // Parse JSON to validate it
      let jsonObject = try JSONSerialization.jsonObject(with: data)
      
      // Save to file
      guard let path = configManager.getConfigurationPath() else {
        showError("No configuration file path")
        return
      }
      
      let url = URL(fileURLWithPath: path)
      
      // Create directory if needed
      let directory = url.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      
      // Write formatted JSON
      let formattedData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
      try formattedData.write(to: url)
      
      // Update editor text with formatted version
      if let formattedString = String(data: formattedData, encoding: .utf8) {
        jsonText = formattedString
      }
      
      // Reload configuration in manager
      configManager.loadConfiguration()
      
      // Set the config path to Claude's default location (since we're now always using it)
      let homeURL = FileManager.default.homeDirectoryForCurrentUser
      let configPath = homeURL
        .appendingPathComponent(".config/claude/mcp-config.json")
        .path
      UserDefaults.standard.set(configPath, forKey: "global.mcpConfigPath")
      
      hasChanges = false
      
      // Close the editor after successful save
      isPresented = false
    } catch let error as NSError {
      // Provide more specific error messages for JSON parsing errors
      if error.domain == NSCocoaErrorDomain {
        let userInfo = error.userInfo
        if let debugDescription = userInfo["NSDebugDescription"] as? String {
          showError("Invalid JSON: \(debugDescription)")
        } else {
          showError("Invalid JSON format. Please check for missing commas, brackets, or quotes.")
        }
      } else {
        showError("Failed to save: \(error.localizedDescription)")
      }
    }
  }
  
  private func formatJSON() {
    guard let data = jsonText.data(using: .utf8) else {
      showError("Invalid text encoding")
      return
    }
    
    do {
      let jsonObject = try JSONSerialization.jsonObject(with: data)
      let formattedData = try JSONSerialization.data(withJSONObject: jsonObject, options: [.prettyPrinted, .sortedKeys])
      jsonText = String(data: formattedData, encoding: .utf8) ?? jsonText
      hasChanges = true
    } catch let error as NSError {
      // Provide more specific error messages
      if error.domain == NSCocoaErrorDomain {
        let userInfo = error.userInfo
        if let debugDescription = userInfo["NSDebugDescription"] as? String {
          showError("Cannot format - Invalid JSON: \(debugDescription)")
        } else {
          showError("Cannot format - Invalid JSON. Please fix syntax errors first.")
        }
      } else {
        showError("Failed to format: \(error.localizedDescription)")
      }
    }
  }
  
  private func reloadFromFile() {
    if hasChanges {
      // Show confirmation dialog
      let alert = NSAlert()
      alert.messageText = "Discard Changes?"
      alert.informativeText = "You have unsaved changes. Are you sure you want to reload from file?"
      alert.addButton(withTitle: "Reload")
      alert.addButton(withTitle: "Cancel")
      alert.alertStyle = .warning
      
      if alert.runModal() == .alertFirstButtonReturn {
        loadConfiguration()
      }
    } else {
      loadConfiguration()
    }
  }
  
  private func openInExternalEditor() {
    guard let path = configManager.getConfigurationPath() else {
      showError("No configuration file to open")
      return
    }
    
    // Open with default text editor
    NSWorkspace.shared.open(URL(fileURLWithPath: path))
    
    // Alternative: Open with specific app (e.g., VSCode with debug flags)
    // You can customize this based on user preferences
    /*
     let process = Process()
     process.launchPath = "/usr/bin/open"
     process.arguments = ["-a", "Visual Studio Code", "--args", "--verbose", path]
     process.launch()
     */
  }
  
  private func showUnsavedChangesAlert() {
    let alert = NSAlert()
    alert.messageText = "Unsaved Changes"
    alert.informativeText = "You have unsaved changes. Do you want to save them before closing?"
    alert.addButton(withTitle: "Save")
    alert.addButton(withTitle: "Don't Save")
    alert.addButton(withTitle: "Cancel")
    alert.alertStyle = .warning
    
    switch alert.runModal() {
    case .alertFirstButtonReturn:
      saveConfiguration()
    case .alertSecondButtonReturn:
      isPresented = false
    default:
      break
    }
  }
  
  private func showError(_ message: String) {
    errorMessage = message
    showingError = true
  }
}
