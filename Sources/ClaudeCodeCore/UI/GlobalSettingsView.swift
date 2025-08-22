//
//  GlobalSettingsView.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import SwiftUI

struct GlobalSettingsView: View {
  // MARK: - Constants
  private enum Layout {
    static let windowWidth: CGFloat = 700
    static let windowHeight: CGFloat = 550
    static let tabPaddingHorizontal: CGFloat = 20
    static let tabPaddingVertical: CGFloat = 10
    static let segmentedPickerWidth: CGFloat = 200
    static let maxTurnsFieldWidth: CGFloat = 80
    static let textEditorHeight: CGFloat = 60
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
  
  // MARK: - Properties
  @Environment(\.dismiss) private var dismiss
  @Environment(GlobalPreferencesStorage.self) private var globalPreferences
  @State private var appearanceSettings = AppearanceSettings()
  @State private var selectedTab = Tab.appearance.rawValue
  @State private var showingToolsEditor = false
  @State private var showingMCPConfig = false
  @State private var selectedTools: Set<String> = []
  
  private let availableTools = ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write", "NotebookRead", "NotebookEdit", "WebSearch", "Task"]
  
  // MARK: - Body
  var body: some View {
    VStack(spacing: 0) {
      tabSelector
      Divider()
      contentView
    }
    .frame(width: Layout.windowWidth, height: Layout.windowHeight)
    .background(Color(NSColor.windowBackgroundColor))
    .sheet(isPresented: $showingToolsEditor) {
      toolsSelectionSheet
    }
    .sheet(isPresented: $showingMCPConfig) {
      mcpConfigurationSheet
    }
    .onAppear {
      selectedTools = Set(globalPreferences.allowedTools)
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
        get: { Set(globalPreferences.allowedTools) },
        set: { globalPreferences.allowedTools = Array($0) }
      ),
      availableTools: availableTools
    )
  }
  
  private var mcpConfigurationSheet: some View {
    MCPConfigurationView(
      isPresented: $showingMCPConfig,
      mcpConfigStorage: globalPreferences,
      globalPreferences: globalPreferences
    )
  }
  
  // MARK: - Preferences View
  private var preferencesView: some View {
    @Bindable var preferences = globalPreferences
    return VStack(spacing: 0) {
      Form {
        claudeCodeConfigurationSection
        resetSection
      }
      .formStyle(.grouped)
    }
  }
  
  // MARK: - Configuration Sections
  private var claudeCodeConfigurationSection: some View {
    Section("ClaudeCode Configuration") {
      maxTurnsRow
      systemPromptRow
      appendSystemPromptRow
      allowedToolsRow
      mcpConfigurationRow
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
  private var maxTurnsRow: some View {
    @Bindable var preferences = globalPreferences
    HStack {
      Text("Max Turns")
      Spacer()
      TextField("Max Turns", value: $preferences.maxTurns, format: .number)
        .textFieldStyle(.roundedBorder)
        .frame(width: Layout.maxTurnsFieldWidth)
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
        Text("Allowed Tools")
        Spacer()
        Button("Edit Tools") {
          showingToolsEditor = true
        }
        .buttonStyle(.bordered)
      }
      Text("\(globalPreferences.allowedTools.count) tools selected")
        .font(.caption)
        .foregroundColor(.secondary)
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
  
  // MARK: - Helper Views
  private var mcpConfigurationControls: some View {
    HStack {
      mcpConfigurationStatus
      
      Button("Configure") {
        showingMCPConfig = true
      }
      .buttonStyle(.borderedProminent)
      
      if !globalPreferences.mcpConfigPath.isEmpty {
        Button("Clear") {
          globalPreferences.mcpConfigPath = ""
        }
        .buttonStyle(.bordered)
      }
    }
  }
  
  private var mcpConfigurationStatus: some View {
    Group {
      if globalPreferences.mcpConfigPath.isEmpty {
        Text("No configuration selected")
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, alignment: .leading)
      } else {
        Text(URL(fileURLWithPath: globalPreferences.mcpConfigPath).lastPathComponent)
          .lineLimit(1)
          .truncationMode(.middle)
          .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
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
}


#Preview {
  GlobalSettingsView()
}
