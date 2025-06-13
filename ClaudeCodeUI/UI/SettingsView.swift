//
//  SettingsView.swift
//  ClaudeCodeUI
//
//  Created on 12/6/2025.
//

import SwiftUI
import AppKit

struct SettingsView: View {
  @Environment(\.dismiss) private var dismiss
  @State private var settingsStorage: SettingsStorage
  @State private var showingProjectPicker = false
  
  init(settingsStorage: SettingsStorage) {
    _settingsStorage = State(initialValue: settingsStorage)
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
                  }
                  .buttonStyle(.bordered)
                }
              }
            }
            .padding(.vertical, 8)
          }
          
          Section("Appearance") {
            Picker("Color Scheme", selection: Binding(
              get: { settingsStorage.colorScheme },
              set: { settingsStorage.colorScheme = $0 }
            )) {
              Text("System").tag("system")
              Text("Light").tag("light")
              Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            
            VStack(alignment: .leading, spacing: 8) {
              Text("Font Size: \(Int(settingsStorage.fontSize))pt")
              Slider(value: Binding(
                get: { settingsStorage.fontSize },
                set: { settingsStorage.fontSize = $0 }
              ), in: 10...20, step: 1)
            }
            .padding(.vertical, 4)
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
      .navigationTitle("Settings")
      .frame(width: 600, height: 400)
    }
  }
  
  private func selectProjectPath() {
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
          }
        }
      }
    } else {
      if panel.runModal() == .OK, let url = panel.url {
        Task { @MainActor in
          settingsStorage.setProjectPath(url.path)
        }
      }
    }
  }
}

#Preview {
  SettingsView(settingsStorage: SettingsStorageManager())
}
