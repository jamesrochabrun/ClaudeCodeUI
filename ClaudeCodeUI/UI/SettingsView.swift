//
//  SettingsView.swift
//  ClaudeCodeUI
//
//  Created on 12/6/2025.
//

import SwiftUI
import AppKit
import ClaudeCodeSDK
import PermissionsServiceInterface

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  let chatViewModel: ChatViewModel
  let xcodeObservationViewModel: XcodeObservationViewModel
  let permissionsService: PermissionsService
  
  var settingsStorage: SettingsStorage {
    chatViewModel.settingsStorage
  }
  
  @State private var projectPath: String = ""
  @State private var isRequestingPermission: Bool = false
  
  init(chatViewModel: ChatViewModel, xcodeObservationViewModel: XcodeObservationViewModel, permissionsService: PermissionsService) {
    self.chatViewModel = chatViewModel
    self.xcodeObservationViewModel = xcodeObservationViewModel
    self.permissionsService = permissionsService
  }
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Form {
          Section("Working Directory") {
            VStack(alignment: .leading, spacing: 12) {
              Text("Project Path")
                .font(.headline)
              
              HStack {
                Text(projectPath.isEmpty ? "No project selected" : projectPath)
                  .lineLimit(1)
                  .truncationMode(.middle)
                  .foregroundColor(projectPath.isEmpty ? .secondary : .primary)
                  .frame(maxWidth: .infinity, alignment: .leading)
                
                Button("Select") {
                  selectProjectPath()
                }
                .buttonStyle(.borderedProminent)
                
                if !projectPath.isEmpty {
                  Button("Clear") {
                    projectPath = ""
                    saveProjectPath()
                    updateClaudeClient()
                  }
                  .buttonStyle(.bordered)
                }
              }
              
              Text("This working directory is specific to this session. Other settings are configured globally via ⌘⇧,")
                .font(.caption)
                .foregroundColor(.secondary)
            }
            .padding(.vertical, 8)
          }
          
          Section("Xcode Integration") {
            VStack(alignment: .leading, spacing: 12) {
              Text("Accessibility Permission")
                .font(.headline)
              
              HStack {
                VStack(alignment: .leading, spacing: 4) {
                  Text(xcodeObservationViewModel.hasAccessibilityPermission ? "Permission Granted" : "Permission Required")
                    .foregroundColor(xcodeObservationViewModel.hasAccessibilityPermission ? .primary : .secondary)
                  
                  Text("Grant accessibility permission to observe Xcode and capture code selections")
                    .font(.caption)
                    .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                if !xcodeObservationViewModel.hasAccessibilityPermission {
                  Button("Grant Permission") {
                    requestAccessibilityPermission()
                  }
                  .buttonStyle(.borderedProminent)
                  .disabled(isRequestingPermission)
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
      .frame(width: 600, height: 350)
    }
    .onAppear {
      loadProjectPath()
    }
  }
  
  private func loadProjectPath() {
    // Load session-specific path if available
    if let sessionId = chatViewModel.currentSessionId,
       let sessionPath = settingsStorage.getProjectPath(forSessionId: sessionId) {
      projectPath = sessionPath
      print("[SettingsView] Loaded project path '\(sessionPath)' for session '\(sessionId)'")
    } else {
      // Fall back to current working directory
      projectPath = chatViewModel.claudeClient.configuration.workingDirectory ?? ""
      print("[SettingsView] No session ID or no saved path. Session ID: \(chatViewModel.currentSessionId ?? "nil"), using working directory: '\(projectPath)'")
    }
  }
  
  private func saveProjectPath() {
    // Save to global setting
    settingsStorage.setProjectPath(projectPath)
    
    // Also save session-specific if we have a session
    if let sessionId = chatViewModel.currentSessionId {
      settingsStorage.setProjectPath(projectPath, forSessionId: sessionId)
      print("[SettingsView] Saved project path '\(projectPath)' for session '\(sessionId)'")
    } else {
      print("[SettingsView] WARNING: No session ID available when saving project path '\(projectPath)'")
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
            projectPath = url.path
            saveProjectPath()
            updateClaudeClient()
          }
        }
      }
    } else {
      if panel.runModal() == .OK, let url = panel.url {
        Task { @MainActor in
          projectPath = url.path
          saveProjectPath()
          updateClaudeClient()
        }
      }
    }
  }
  
  private func updateClaudeClient() {
    // Update the ClaudeCode client configuration directly
    let workingDirectory = projectPath
    
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
  
  private func requestAccessibilityPermission() {
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
}
