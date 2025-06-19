//
//  SettingsView.swift
//  ClaudeCodeUI
//
//  Created on 12/6/2025.
//

import SwiftUI
import AppKit
import ClaudeCodeSDK

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  let chatViewModel: ChatViewModel
  var settingsStorage: SettingsStorage {
    chatViewModel.settingsStorage
  }
  @State private var showingProjectPicker = false
  @State private var selectedTools: Set<String> = []
  @State private var showingToolsEditor = false
  
  private let availableTools = ["Bash", "LS", "Read", "WebFetch", "Batch", "TodoRead/Write", "Glob", "Grep", "Edit", "MultiEdit", "Write", "NotebookRead", "NotebookEdit", "WebSearch", "Task"]
  
  init(chatViewModel: ChatViewModel) {
    self.chatViewModel = chatViewModel
    _selectedTools = State(initialValue: Set(chatViewModel.settingsStorage.allowedTools))
  }
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Form {
          Section("Project Settings") {
            VStack(alignment: .leading, spacing: 12) {
              Text("Project Path")
                .font(.headline)
              
              HStack {
                Text(settingsStorage.projectPath.isEmpty ? "No project selected" : settingsStorage.projectPath)
                  .lineLimit(1)
                  .truncationMode(.middle)
                  .foregroundColor(settingsStorage.projectPath.isEmpty ? .secondary : .primary)
                  .frame(maxWidth: .infinity, alignment: .leading)
                
                Button("Select") {
                  selectProjectPath()
                }
                .buttonStyle(.borderedProminent)
                
                if !settingsStorage.projectPath.isEmpty {
                  Button("Clear") {
                    settingsStorage.clearProjectPath()
                    updateClaudeClient()
                  }
                  .buttonStyle(.bordered)
                }
              }
            }
            .padding(.vertical, 8)
          }
          
          Section("ClaudeCode Configuration") {
            Toggle("Verbose Mode", isOn: Binding(
              get: { settingsStorage.verboseMode },
              set: { settingsStorage.verboseMode = $0 }
            ))
            
            HStack {
              Text("Max Turns")
              Spacer()
              TextField("Max Turns", value: Binding(
                get: { settingsStorage.maxTurns },
                set: { settingsStorage.maxTurns = $0 }
              ), format: .number)
              .textFieldStyle(.roundedBorder)
              .frame(width: 80)
            }
            
            VStack(alignment: .leading, spacing: 8) {
              Text("System Prompt")
              TextEditor(text: Binding(
                get: { settingsStorage.systemPrompt },
                set: { settingsStorage.systemPrompt = $0 }
              ))
              .font(.system(.body, design: .monospaced))
              .frame(height: 60)
              .overlay(
                RoundedRectangle(cornerRadius: 4)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
            }
            
            VStack(alignment: .leading, spacing: 8) {
              Text("Append System Prompt")
              TextEditor(text: Binding(
                get: { settingsStorage.appendSystemPrompt },
                set: { settingsStorage.appendSystemPrompt = $0 }
              ))
              .font(.system(.body, design: .monospaced))
              .frame(height: 60)
              .overlay(
                RoundedRectangle(cornerRadius: 4)
                  .stroke(Color.secondary.opacity(0.2), lineWidth: 1)
              )
            }
            
            VStack(alignment: .leading, spacing: 8) {
              HStack {
                Text("Allowed Tools")
                Spacer()
                Button("Edit Tools") {
                  showingToolsEditor = true
                }
                .buttonStyle(.bordered)
              }
              Text("\(settingsStorage.allowedTools.count) tools selected")
                .font(.caption)
                .foregroundColor(.secondary)
            }
          }
          
          Section {
            Button("Reset All Settings") {
              settingsStorage.resetAllSettings()
            }
            .foregroundColor(.red)
          }
        }
        .formStyle(.grouped)
        
        Divider()
        
        HStack {
          Spacer()
          Button("Done") {
            dismiss()
          }
          .buttonStyle(.borderedProminent)
          .keyboardShortcut(.defaultAction)
        }
        .padding()
      }
      .navigationTitle("Session Settings")
      .frame(width: 700, height: 550)
    }
    .sheet(isPresented: $showingToolsEditor) {
      ToolsSelectionView(selectedTools: $selectedTools, availableTools: availableTools) {
        settingsStorage.setAllowedTools(Array(selectedTools))
      }
    }
  }
  
  private func selectProjectPath() {
    // Check if there are messages in the current conversation
    if !chatViewModel.messages.isEmpty {
      // Show warning alert
      let alert = NSAlert()
      alert.messageText = "Change Project Directory?"
      alert.informativeText = "Changing the project directory will end your current conversation. Do you want to continue?"
      alert.addButton(withTitle: "Change Directory")
      alert.addButton(withTitle: "Cancel")
      alert.alertStyle = .warning
      
      if alert.runModal() == .alertFirstButtonReturn {
        // User confirmed - proceed with directory change
        showDirectoryPicker()
      }
    } else {
      // No messages - safe to change directory
      showDirectoryPicker()
    }
  }
  
  private func showDirectoryPicker() {
    let panel = NSOpenPanel()
    panel.title = "Select Project Directory"
    panel.message = "Choose a project directory to use with ClaudeCode"
    panel.prompt = "Select"
    panel.allowsMultipleSelection = false
    panel.canChooseFiles = false
    panel.canChooseDirectories = true
    panel.canCreateDirectories = false
    panel.showsHiddenFiles = false
    
    if let window = NSApp.keyWindow {
      panel.beginSheetModal(for: window) { response in
        if response == .OK, let url = panel.url {
          Task { @MainActor in
            settingsStorage.setProjectPath(url.path)
            updateClaudeClient()
          }
        }
      }
    } else {
      if panel.runModal() == .OK, let url = panel.url {
        Task { @MainActor in
          settingsStorage.setProjectPath(url.path)
          updateClaudeClient()
        }
      }
    }
  }
  
  private func updateClaudeClient() {
    // Update the ClaudeCode client configuration directly
    let workingDirectory = settingsStorage.getProjectPath() ?? ""
    
    // Check if working directory changed
    let currentWorkingDir = chatViewModel.claudeClient.configuration.workingDirectory
    let newWorkingDir = workingDirectory.isEmpty ? nil : workingDirectory
    
    if currentWorkingDir != newWorkingDir && !chatViewModel.messages.isEmpty {
      // Clear conversation when working directory changes and there are messages
      chatViewModel.clearConversation()
    }
    
    // Update configuration properties
    chatViewModel.claudeClient.configuration.workingDirectory = newWorkingDir
    
    // Update the observable project path in the view model
    chatViewModel.refreshProjectPath()
  }
}

#Preview {
  let dependencyContainer = DependencyContainer()
  let claudeClient = ClaudeCodeClient(workingDirectory: "", debug: false)
  let viewModel = ChatViewModel(
    claudeClient: claudeClient,
    sessionStorage: dependencyContainer.sessionStorage,
    settingsStorage: dependencyContainer.settingsStorage
  )
  return SettingsView(chatViewModel: viewModel)
}
