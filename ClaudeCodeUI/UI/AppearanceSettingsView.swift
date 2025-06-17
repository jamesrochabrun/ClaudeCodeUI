//
//  AppearanceSettingsView.swift
//  ClaudeCodeUI
//
//  Created on 12/14/2025.
//

import SwiftUI

struct AppearanceSettingsView: View {
  let globalSettingsStorage: GlobalSettingsStorage
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        Form {
          Section("Appearance") {
            Picker("Color Scheme", selection: Binding(
              get: { globalSettingsStorage.colorScheme },
              set: { globalSettingsStorage.colorScheme = $0 }
            )) {
              Text("System").tag("system")
              Text("Light").tag("light")
              Text("Dark").tag("dark")
            }
            .pickerStyle(.segmented)
            
            VStack(alignment: .leading, spacing: 8) {
              Text("Font Size: \(Int(globalSettingsStorage.fontSize))pt")
              Slider(value: Binding(
                get: { globalSettingsStorage.fontSize },
                set: { globalSettingsStorage.fontSize = $0 }
              ), in: 10...20, step: 1)
            }
            .padding(.vertical, 4)
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
      .navigationTitle("Appearance Settings")
      .frame(width: 400, height: 200)
    }
  }
}

#Preview {
  AppearanceSettingsView(globalSettingsStorage: GlobalSettingsStorageManager())
}