//
//  GlobalSettingsView.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import SwiftUI
import AppKit
import CCPermissionsServiceInterface

struct GlobalSettingsView: View {
  let uiConfiguration: UIConfiguration
  let xcodeObservationViewModel: XcodeObservationViewModel?
  let permissionsService: PermissionsService?
  let chatViewModel: ChatViewModel?

  init(
    uiConfiguration: UIConfiguration = .default,
    xcodeObservationViewModel: XcodeObservationViewModel? = nil,
    permissionsService: PermissionsService? = nil,
    chatViewModel: ChatViewModel? = nil
  ) {
    self.uiConfiguration = uiConfiguration
    self.xcodeObservationViewModel = xcodeObservationViewModel
    self.permissionsService = permissionsService
    self.chatViewModel = chatViewModel
  }
  
  // MARK: - Constants
  private enum Layout {
    static let windowWidth: CGFloat = 700
    static let windowHeight: CGFloat = 550
    static let tabPaddingHorizontal: CGFloat = 20
    static let tabPaddingVertical: CGFloat = 10
    static let segmentedPickerWidth: CGFloat = 200
    static let textEditorHeight: CGFloat = 100
  }
  
  private enum Tab: Int, CaseIterable {
    case appearance = 0
    case preferences = 1

    var title: String {
      switch self {
      case .appearance: return "Appearance"
      case .preferences: return "Preferences"
      }
    }
  }

  private enum PathValidationState {
    case notSet
    case valid
    case invalid
  }
  
  // MARK: - Properties
  @Environment(\.dismiss) private var dismiss
  @Environment(GlobalPreferencesStorage.self) private var globalPreferences
  @State private var appearanceSettings = AppearanceSettings()
  @State private var selectedTab = Tab.preferences.rawValue
  @State private var showingToolsEditor = false
  @State private var showingMCPConfig = false
  @State private var selectedTools: Set<String> = []
  @State private var selectedMCPTools: [String: Set<String>] = [:]
  @State private var isRequestingPermission: Bool = false
  @State private var commandCopied: Bool = false
  @State private var reportCopied: Bool = false
  @State private var claudePathValidation: PathValidationState = .notSet

  // MARK: - Body
  var body: some View {
    VStack(spacing: 0) {
      tabSelector
      Divider()
      contentView
    }
    .frame(width: Layout.windowWidth, height: Layout.windowHeight)
    .background(Color(NSColor.windowBackgroundColor))
    .toolbar {
      ToolbarItem(placement: .confirmationAction) {
        Button("Done") {
          // Update the Claude command in the view model if it exists
          if let viewModel = chatViewModel {
            viewModel.updateClaudeCommand(from: globalPreferences)
          }
          dismiss()
        }
        .disabled(claudePathValidation == .invalid)
      }
    }
    .sheet(isPresented: $showingToolsEditor) {
      toolsSelectionSheet
    }
    .sheet(isPresented: $showingMCPConfig) {
      mcpConfigurationSheet
    }
    .onAppear {
      let claudeTools = ClaudeCodeTool.allCases.map { $0.rawValue }
      selectedTools = Set(globalPreferences.allowedTools.filter { claudeTools.contains($0) })
      selectedMCPTools = globalPreferences.selectedMCPTools
    }
  }
  
  // MARK: - Tab Selector
  private var tabSelector: some View {
    HStack {
      Picker("", selection: $selectedTab) {
        ForEach(Tab.allCases, id: \.rawValue) { tab in
          Text(tab.title).tag(tab.rawValue)
        }
      }
      .pickerStyle(.segmented)
      .frame(width: Layout.segmentedPickerWidth)
      
      Spacer()
    }
    .padding(.horizontal, Layout.tabPaddingHorizontal)
    .padding(.vertical, Layout.tabPaddingVertical)
    .background(Color(NSColor.windowBackgroundColor))
  }
  
  // MARK: - Content View
  private var contentView: some View {
    Group {
      if selectedTab == Tab.appearance.rawValue {
        AppearanceView(appearanceSettings: appearanceSettings)
      } else {
        preferencesView
      }
    }
    .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
  
  // MARK: - Sheets
  private var toolsSelectionSheet: some View {
    ToolsSelectionView(
      selectedTools: Binding(
        get: {
          // Filter Claude Code tools from allowedTools (exclude MCP tools)
          let tools = Set(globalPreferences.allowedTools.filter { !$0.hasPrefix("mcp__") })
          return tools
        },
        set: { newTools in
          // Combine Claude Code tools with selected MCP tools (properly formatted)
          var allTools = Array(newTools)
          
          // Add MCP tools with proper formatting: mcp__<server>__<tool>
          for (server, tools) in globalPreferences.selectedMCPTools {
            for tool in tools {
              let formattedTool = "mcp__\(server)__\(tool)"
              allTools.append(formattedTool)
            }
          }
          globalPreferences.allowedTools = allTools
        }
      ),
      selectedMCPTools: Binding(
        get: { globalPreferences.selectedMCPTools },
        set: { newMCPTools in
          globalPreferences.selectedMCPTools = newMCPTools
          
          // Also update allowedTools with the new MCP tools
          // Get current Claude Code tools (exclude MCP tools)
          var allTools = globalPreferences.allowedTools.filter { !$0.hasPrefix("mcp__") }
          
          // Add MCP tools with proper formatting: mcp__<server>__<tool>
          for (server, tools) in newMCPTools {
            for tool in tools {
              let formattedTool = "mcp__\(server)__\(tool)"
              allTools.append(formattedTool)
            }
          }
          globalPreferences.allowedTools = allTools
        }
      ),
      availableToolsByServer: getAvailableToolsByServer()
    )
  }
  
  private func getAvailableToolsByServer() -> [String: [String]] {
    // Get all discovered tools from MCPToolsDiscoveryService
    let discoveredTools = MCPToolsDiscoveryService.shared.getAllAvailableTools()
    
    if !discoveredTools.isEmpty {
      // Use discovered tools if available (from system init message)
      return discoveredTools
    } else {
      // Fallback to hardcoded tools if no discovery has happened yet
      var toolsByServer: [String: [String]] = [:]
      toolsByServer["Claude Code"] = ClaudeCodeTool.allCases.map { $0.rawValue }
      
      // Add any stored MCP tools from preferences
      for (server, tools) in globalPreferences.mcpServerTools {
        toolsByServer[server] = tools
      }
      
      return toolsByServer
    }
  }
  
  private var mcpConfigurationSheet: some View {
    MCPConfigurationView(
      isPresented: $showingMCPConfig,
      mcpConfigStorage: globalPreferences,
      globalPreferences: globalPreferences,
      uiConfiguration: uiConfiguration
    )
  }
  
  // MARK: - Preferences View
  private var preferencesView: some View {
    @Bindable var preferences = globalPreferences
    return VStack(spacing: 0) {
      Form {
        if xcodeObservationViewModel != nil && permissionsService != nil {
          xcodeIntegrationSection
        }
        claudeCodeConfigurationSection
        debugSection
        resetSection
      }
      .formStyle(.grouped)

      Divider()

      // Version footer
      HStack {
        Spacer()
        Text(VersionProvider.formattedVersion)
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.horizontal)
      .padding(.vertical, 8)
      .background(Color(NSColor.windowBackgroundColor))
    }
  }
  
  // MARK: - Configuration Sections
  private var claudeCodeConfigurationSection: some View {
    Section("ClaudeCode Configuration") {
      defaultWorkingDirectoryRow
      claudeCommandRow
      claudePathRow
      if uiConfiguration.showSystemPromptFields {
        systemPromptRow
      }
      if uiConfiguration.showAdditionalSystemPromptField {
        appendSystemPromptRow
      }
      allowedToolsRow
      mcpConfigurationRow
    }
  }

  private var xcodeIntegrationSection: some View {
    Section("Xcode Integration") {
      VStack(alignment: .leading, spacing: 12) {
        Text("Accessibility Permission")
          .font(.headline)

        HStack {
          VStack(alignment: .leading, spacing: 4) {
            Text(xcodeObservationViewModel?.hasAccessibilityPermission ?? false ? "Permission Granted" : "Permission Required")
              .foregroundColor(xcodeObservationViewModel?.hasAccessibilityPermission ?? false ? .primary : .secondary)

            Text("Grant accessibility permission to observe Xcode and capture code selections")
              .font(.caption)
              .foregroundColor(.secondary)
          }
          .frame(maxWidth: .infinity, alignment: .leading)

          if !(xcodeObservationViewModel?.hasAccessibilityPermission ?? false) {
            Button("Grant Permission") {
              requestAccessibilityPermission()
            }
            .buttonStyle(.borderedProminent)
            .disabled(isRequestingPermission || permissionsService == nil)
          } else {
            Image(systemName: "checkmark.circle.fill")
              .foregroundColor(.green)
          }
        }

        Text("Use ⌘I to capture code selections from Xcode")
          .font(.caption)
          .foregroundColor(.secondary)
      }
      .padding(.vertical, 8)
    }
  }
  
  private var debugSection: some View {
    Section("Debug") {
      let hasCommandInfo = chatViewModel?.terminalReproductionCommand != nil

      VStack(alignment: .leading, spacing: 16) {
        // Empty State Info Banner
        if !hasCommandInfo {
          HStack(spacing: 12) {
            Image(systemName: "info.circle.fill")
              .foregroundColor(.blue)
              .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
              Text("Debug Information Not Available")
                .font(.headline)
              Text("Send a message in the chat to generate command execution details.")
                .font(.caption)
                .foregroundColor(.secondary)
            }

            Spacer()
          }
          .padding(12)
          .background(Color.blue.opacity(0.1))
          .cornerRadius(8)
          .overlay(
            RoundedRectangle(cornerRadius: 8)
              .stroke(Color.blue.opacity(0.3), lineWidth: 1)
          )
        }

        // Terminal Reproduction Command
        VStack(alignment: .leading, spacing: 8) {
          Text("Terminal Reproduction Command")
            .font(.headline)

          HStack(alignment: .top, spacing: 12) {
            Text(chatViewModel?.terminalReproductionCommand ?? "No command executed yet")
              .font(.system(.body, design: .monospaced))
              .textSelection(.enabled)
              .frame(maxWidth: .infinity, alignment: .leading)
              .padding(8)
              .background(hasCommandInfo ? Color(NSColor.textBackgroundColor) : Color.secondary.opacity(0.05))
              .cornerRadius(4)
              .overlay(
                RoundedRectangle(cornerRadius: 4)
                  .stroke(hasCommandInfo ? Color.secondary.opacity(0.2) : Color.secondary.opacity(0.15), lineWidth: 1)
              )

            Button(action: {
              copyTerminalCommandToClipboard()
            }) {
              Image(systemName: commandCopied ? "checkmark" : "doc.on.doc")
                .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasCommandInfo)
            .help(hasCommandInfo ? "Copy terminal command to clipboard" : "Send a message first to generate debug info")
          }

          Text("Copy this command to paste into Terminal and reproduce the last execution")
            .font(.caption)
            .foregroundColor(.secondary)
        }

        Divider()

        // Full Debug Report
        VStack(alignment: .leading, spacing: 8) {
          DisclosureGroup("Full Debug Report") {
            ScrollView {
              if hasCommandInfo {
                Text(chatViewModel?.fullDebugReport ?? "")
                  .font(.system(.caption, design: .monospaced))
                  .textSelection(.enabled)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .padding(8)
              } else {
                VStack(spacing: 8) {
                  Image(systemName: "doc.text.magnifyingglass")
                    .font(.largeTitle)
                    .foregroundColor(.secondary)
                  Text("No debug information available")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                  Text("Execute a command first to see detailed debug information")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(24)
              }
            }
            .frame(height: 200)
            .background(hasCommandInfo ? Color(NSColor.textBackgroundColor) : Color.secondary.opacity(0.05))
            .cornerRadius(4)
            .overlay(
              RoundedRectangle(cornerRadius: 4)
                .stroke(hasCommandInfo ? Color.secondary.opacity(0.2) : Color.secondary.opacity(0.15), lineWidth: 1)
            )

            HStack {
              Spacer()
              Button(action: {
                copyFullReportToClipboard()
              }) {
                HStack(spacing: 4) {
                  Image(systemName: reportCopied ? "checkmark" : "doc.on.doc")
                  Text("Copy Full Report")
                }
              }
              .buttonStyle(.borderedProminent)
              .disabled(!hasCommandInfo)
              .help(hasCommandInfo ? "Copy complete debug report to clipboard" : "Send a message first to generate debug info")
              .padding(.top, 8)
            }
          }

          Text("Complete report with all command details, environment, and PATH information")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
      .padding(.vertical, 8)
    }
  }

  private var resetSection: some View {
    Section {
      Button("Reset All Settings") {
        globalPreferences.resetToDefaults()
      }
      .foregroundColor(.red)
    }
  }

  // MARK: - Configuration Rows
  @ViewBuilder
  private var defaultWorkingDirectoryRow: some View {
    @Bindable var preferences = globalPreferences
    VStack(alignment: .leading, spacing: 8) {
      Text("Default Working Directory")
      HStack {
        Text(preferences.defaultWorkingDirectory.isEmpty ? "No default directory set" : preferences.defaultWorkingDirectory)
          .lineLimit(1)
          .truncationMode(.middle)
          .foregroundColor(preferences.defaultWorkingDirectory.isEmpty ? .secondary : .primary)
          .frame(maxWidth: .infinity, alignment: .leading)

        Button("Select") {
          selectDefaultWorkingDirectory()
        }

        if !preferences.defaultWorkingDirectory.isEmpty {
          Button("Clear") {
            preferences.defaultWorkingDirectory = ""
          }
          .foregroundColor(.red)
        }
      }
      Text("New sessions will use this directory by default")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }

  @ViewBuilder
  private var claudeCommandRow: some View {
    @Bindable var preferences = globalPreferences
    VStack(alignment: .leading, spacing: 8) {
      Text("Claude Command")
      if preferences.isClaudeCommandFromConfig {
        // Show static text when command is from configuration
        HStack {
          Text(preferences.claudeCommand)
            .font(.system(.body, design: .monospaced))
            .foregroundColor(.secondary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(8)
            .background(Color(NSColor.textBackgroundColor).opacity(0.5))
            .cornerRadius(4)
            .overlay(
              RoundedRectangle(cornerRadius: 4)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
            )

          Image(systemName: "lock.fill")
            .foregroundColor(.secondary)
            .help("Command is set by configuration and cannot be changed")
        }
        Text("This command is configured by the app and cannot be changed from preferences")
          .font(.caption)
          .foregroundColor(.secondary)
      } else {
        // Show editable TextField when command is not from configuration
        HStack {
          TextField("Command", text: $preferences.claudeCommand)
            .textFieldStyle(.roundedBorder)
            .font(.system(.body, design: .monospaced))

          if preferences.claudeCommand != "claude" {
            Button("Reset") {
              preferences.claudeCommand = "claude"
            }
            .foregroundColor(.orange)
          }
        }
        Text("The command to execute Claude Code (default: 'claude')")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }

  @ViewBuilder
  private var claudePathRow: some View {
    @Bindable var preferences = globalPreferences
    VStack(alignment: .leading, spacing: 8) {
      Text("\(preferences.claudeCommand) Path (Advanced)")
      HStack {
        TextField("Path to \(preferences.claudeCommand) executable", text: $preferences.claudePath)
          .textFieldStyle(.roundedBorder)
          .font(.system(.body, design: .monospaced))
          .onChange(of: preferences.claudePath) { oldValue, newValue in
            validateClaudePath(newValue)
          }

        // Validation indicator
        if !preferences.claudePath.isEmpty {
          Group {
            switch claudePathValidation {
            case .valid:
              Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            case .invalid:
              Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
            case .notSet:
              EmptyView()
            }
          }
          .help(claudePathValidation == .valid ? "Path exists" : "Path not found")
        }

        if !preferences.claudePath.isEmpty {
          Button("Clear") {
            preferences.claudePath = ""
            claudePathValidation = .notSet
          }
          .foregroundColor(.orange)
        }
      }
      VStack(alignment: .leading, spacing: 4) {
        if claudePathValidation == .invalid {
          Text("❌ Path does not exist - please check the path and try again")
            .font(.caption)
            .foregroundColor(.red)
        }
        Text("⚠️ Only use this if you see '\(preferences.claudeCommand) not installed' errors")
          .font(.caption)
          .foregroundColor(.orange)
        Text("Run 'which \(preferences.claudeCommand)' in Terminal and paste the output here")
          .font(.caption)
          .foregroundColor(.secondary)
        Text("Example: /Users/you/.nvm/versions/node/v22.16.0/bin/\(preferences.claudeCommand)")
          .font(.caption)
          .foregroundColor(.secondary.opacity(0.7))
      }
    }
    .onAppear {
      validateClaudePath(preferences.claudePath)
    }
  }

  @ViewBuilder
  private var systemPromptRow: some View {
    @Bindable var preferences = globalPreferences
    VStack(alignment: .leading, spacing: 8) {
      Text("System Prompt")
      promptTextEditor(text: $preferences.systemPrompt)
    }
  }
  
  @ViewBuilder
  private var appendSystemPromptRow: some View {
    @Bindable var preferences = globalPreferences
    VStack(alignment: .leading, spacing: 8) {
      Text("Append System Prompt")
      promptTextEditor(text: $preferences.appendSystemPrompt)
    }
  }
  
  private var allowedToolsRow: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Text("Auto-Approved Tools")
        Spacer()
        Button("Configure Auto-Approval") {
          showingToolsEditor = true
        }
        .buttonStyle(.bordered)
      }

      // Show corruption warning if preferences are corrupted
      if globalPreferences.hasCorruptedPreferences {
        VStack(alignment: .leading, spacing: 8) {
          HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
              .foregroundColor(.orange)
              .imageScale(.large)
            VStack(alignment: .leading, spacing: 4) {
              Text("Preferences File Corrupted")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
              Text("Your preferences file was corrupted. For safety, no tools are auto-approved.")
                .font(.caption)
                .foregroundColor(.secondary)
              if let error = globalPreferences.corruptionError {
                Text(error.localizedDescription)
                  .font(.caption2)
                  .foregroundColor(.secondary)
                  .italic()
              }
            }
            Spacer()
          }
          .padding(12)
          .background(Color.orange.opacity(0.1))
          .cornerRadius(8)

          HStack(spacing: 12) {
            if globalPreferences.hasBackupAvailable {
              Button("Restore from Backup") {
                if globalPreferences.restoreFromBackup() {
                  // Successfully restored
                  showingToolsEditor = false
                }
              }
              .buttonStyle(.bordered)
            }

            Button("Reset and Reconfigure") {
              globalPreferences.resetAfterCorruption()
              showingToolsEditor = true
            }
            .buttonStyle(.borderedProminent)
            .foregroundColor(.white)
            .tint(.orange)
          }
        }
      } else {
        Text("\(globalPreferences.allowedTools.count) tools auto-approved")
          .font(.caption)
          .foregroundColor(.secondary)
      }
    }
  }
  
  private var mcpConfigurationRow: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("MCP Configuration")
      mcpConfigurationControls
      Text("Configure MCP servers or select an existing configuration file")
        .font(.caption)
        .foregroundColor(.secondary)
    }
  }
  
  // MARK: - Helper Methods
  private func validateClaudePath(_ path: String) {
    if path.isEmpty {
      claudePathValidation = .notSet
      return
    }

    if FileManager.default.fileExists(atPath: path) {
      claudePathValidation = .valid
    } else {
      claudePathValidation = .invalid
    }
  }

  private func selectDefaultWorkingDirectory() {
    let openPanel = NSOpenPanel()
    openPanel.canChooseFiles = false
    openPanel.canChooseDirectories = true
    openPanel.allowsMultipleSelection = false
    openPanel.message = "Select Default Working Directory"
    openPanel.prompt = "Select"

    if openPanel.runModal() == .OK, let url = openPanel.url {
      globalPreferences.defaultWorkingDirectory = url.path
    }
  }

  private func repairMCPApprovalServer() {
    let mcpConfigManager = MCPConfigurationManager()
    mcpConfigManager.updateApprovalServerPath()

    // Check if it worked
    if mcpConfigManager.configuration.mcpServers["approval_server"] != nil {
      // Success - show an alert
      let alert = NSAlert()
      alert.messageText = "MCP Configuration Repaired"
      alert.informativeText = "The approval server has been successfully configured. Tool approvals will now work properly."
      alert.alertStyle = .informational
      alert.addButton(withTitle: "OK")
      alert.runModal()
    } else {
      // Failed - show error alert
      let alert = NSAlert()
      alert.messageText = "Repair Failed"
      alert.informativeText = "Could not configure the approval server. The ApprovalMCPServer binary may be missing from the app bundle. Please rebuild the app with Xcode."
      alert.alertStyle = .warning
      alert.addButton(withTitle: "OK")
      alert.runModal()
    }
  }

  // MARK: - Helper Views
  private var mcpConfigurationControls: some View {
    HStack {
      mcpConfigurationStatus

      // Repair button for approval server
      Button(action: repairMCPApprovalServer) {
        Label("Repair", systemImage: "wrench.and.screwdriver")
      }
      .buttonStyle(.bordered)
      .help("Repair MCP approval server configuration")

      Button("Configure") {
        showingMCPConfig = true
      }
      .buttonStyle(.borderedProminent)
    }
  }
  
  private var mcpConfigurationStatus: some View {
    Text(globalPreferences.mcpConfigPath)
      .font(.system(.body, design: .monospaced))
      .foregroundColor(.secondary)
      .frame(maxWidth: .infinity, alignment: .leading)
      .lineLimit(1)
      .truncationMode(.middle)
  }
  
  private func promptTextEditor(text: Binding<String>) -> some View {
    TextEditor(text: text)
      .font(.system(.body, design: .monospaced))
      .frame(height: Layout.textEditorHeight)
      .overlay(
        RoundedRectangle(cornerRadius: 4)
          .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
      )
  }

  private func requestAccessibilityPermission() {
    guard let permissionsService = permissionsService else { return }

    isRequestingPermission = true

    Task {
      permissionsService.requestAccessibilityPermission()

      // Wait a moment for the system to update
      try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

      await MainActor.run {
        isRequestingPermission = false
      }
    }
  }

  private func copyTerminalCommandToClipboard() {
    guard let command = chatViewModel?.terminalReproductionCommand else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(command, forType: .string)

    commandCopied = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      commandCopied = false
    }
  }

  private func copyFullReportToClipboard() {
    guard let report = chatViewModel?.fullDebugReport else { return }
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(report, forType: .string)

    reportCopied = true
    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
      reportCopied = false
    }
  }
}


#Preview {
  GlobalSettingsView()
}
