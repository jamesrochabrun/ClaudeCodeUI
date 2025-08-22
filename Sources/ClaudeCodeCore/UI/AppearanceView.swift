//
//  AppearanceView.swift
//  ClaudeCodeUI
//
//  Created on 12/14/2025.
//

import SwiftUI

struct AppearanceView: View {
  // MARK: - Constants
  private enum Layout {
    static let fontSizeRange: ClosedRange<Double> = 10...20
    static let fontSizeStep: Double = 1
    static let sectionSpacing: CGFloat = 8
    static let sectionPadding: CGFloat = 4
  }
  
  private enum ColorScheme: String, CaseIterable {
    case system = "system"
    case light = "light"
    case dark = "dark"
    
    var displayName: String {
      switch self {
      case .system: return "System"
      case .light: return "Light"
      case .dark: return "Dark"
      }
    }
  }
  
  // MARK: - Properties
  @Environment(\.dismiss) private var dismiss
  @Bindable var appearanceSettings: AppearanceSettings
  
  // MARK: - Body
  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        formContent
        Divider()
        bottomToolbar
      }
      .navigationTitle("Appearance Settings")
    }
  }
  
  // MARK: - View Components
  private var formContent: some View {
    Form {
      appearanceSection
    }
    .formStyle(.grouped)
  }
  
  private var appearanceSection: some View {
    Section("Appearance") {
      colorSchemePicker
      fontSizeControls
    }
  }
  
  private var colorSchemePicker: some View {
    Picker("Color Scheme", selection: $appearanceSettings.colorScheme) {
      ForEach(ColorScheme.allCases, id: \.rawValue) { scheme in
        Text(scheme.displayName).tag(scheme.rawValue)
      }
    }
    .pickerStyle(.segmented)
  }
  
  private var fontSizeControls: some View {
    VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
      fontSizeLabel
      fontSizeSlider
    }
    .padding(.vertical, Layout.sectionPadding)
  }
  
  private var fontSizeLabel: some View {
    Text("Font Size: \(formattedFontSize)")
  }
  
  private var fontSizeSlider: some View {
    Slider(
      value: $appearanceSettings.fontSize,
      in: Layout.fontSizeRange,
      step: Layout.fontSizeStep
    )
  }
  
  private var bottomToolbar: some View {
    HStack {
      Spacer()
      doneButton
    }
    .padding()
  }
  
  private var doneButton: some View {
    Button("Done") {
      dismiss()
    }
    .buttonStyle(.borderedProminent)
    .keyboardShortcut(.defaultAction)
  }
  
  // MARK: - Computed Properties
  private var formattedFontSize: String {
    "\(Int(appearanceSettings.fontSize))pt"
  }
}

#Preview {
  AppearanceView(appearanceSettings: AppearanceSettings())
}
