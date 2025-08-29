//
//  AppearanceView.swift
//  ClaudeCodeUI
//
//  Created on 12/14/2025.
//

import SwiftUI
import AppKit

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
      themePicker
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
  
  private var themePicker: some View {
    VStack(alignment: .leading, spacing: Layout.sectionSpacing) {
      Text("Theme")
        .fontWeight(.medium)
      
      Picker("Theme", selection: $appearanceSettings.selectedTheme) {
        ForEach(AppTheme.allCases) { theme in
          Text(theme.displayName)
            .tag(theme)
        }
      }
      .pickerStyle(.segmented)
      // Show the selected theme description below the segmented control
      Text(appearanceSettings.selectedTheme.description)
        .font(.caption)
        .foregroundColor(.secondary)

      // If custom theme is selected, show pickers for custom colors
      if appearanceSettings.selectedTheme == .custom {
        customColorEditors
      }

      // Color preview for selected theme
      themeColorPreview
    }
    .padding(.vertical, Layout.sectionPadding)
  }
  
  private var themeColorPreview: some View {
    HStack(spacing: 12) {
      Text("Colors:")
        .font(.caption)
        .foregroundColor(.secondary)
      
      let colors = getThemeColors(for: appearanceSettings.selectedTheme)
      
      HStack(spacing: 8) {
        ColorSwatch(color: colors.brandPrimary, label: "Primary")
        ColorSwatch(color: colors.brandSecondary, label: "Secondary")
        ColorSwatch(color: colors.brandTertiary, label: "Tertiary")
      }
      
      Spacer()
    }
    .padding(.top, 4)
  }

  // MARK: - Custom Theme Editors
  private var customColorEditors: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Custom Colors")
        .font(.subheadline)
        .foregroundColor(.secondary)
      
      customColorRow(title: "Primary", hexBinding: $appearanceSettings.customPrimaryHex)
      customColorRow(title: "Secondary", hexBinding: $appearanceSettings.customSecondaryHex)
      customColorRow(title: "Tertiary", hexBinding: $appearanceSettings.customTertiaryHex)
    }
    .padding(.vertical, 4)
  }

  private func customColorRow(title: String, hexBinding: Binding<String>) -> some View {
    HStack(spacing: 12) {
      Text(title)
        .frame(width: 70, alignment: .leading)
      
      MacColorWell(color: Binding<NSColor>(
        get: { NSColor.fromHex(hexBinding.wrappedValue) },
        set: { newValue in
          hexBinding.wrappedValue = newValue.toHexString()
        }
      ))
      .frame(width: 44, height: 24)
      
      Text(hexBinding.wrappedValue.uppercased())
        .font(.caption)
        .foregroundColor(.secondary)
      
      Spacer()
    }
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
  
  // MARK: - Helper Methods
  private func getThemeColors(for theme: AppTheme) -> ThemeColors {
    switch theme {
    case .claude:
      return ThemeColors(
        brandPrimary: Color(hex: "#CC785C"),
        brandSecondary: Color(hex: "#D4A27F"),
        brandTertiary: Color(hex: "#EBDBBC")
      )
    case .bat:
      // Bat: purple primary, real mustard secondary, slate tertiary
      return ThemeColors(
        brandPrimary: Color(hex: "#7C3AED"),
        brandSecondary: Color(hex: "#FFB000"),
        brandTertiary: Color(hex: "#64748B")
      )
    case .xcode:
      // Xcode: dynamic system colors akin to Xcode highlights
      return ThemeColors(
        brandPrimary: Color(nsColor: .systemBlue),
        brandSecondary: Color(nsColor: .systemIndigo),
        brandTertiary: Color(nsColor: .systemTeal)
      )
    case .custom:
      return ThemeColors(
        brandPrimary: Color(hex: appearanceSettings.customPrimaryHex),
        brandSecondary: Color(hex: appearanceSettings.customSecondaryHex),
        brandTertiary: Color(hex: appearanceSettings.customTertiaryHex)
      )
    }
  }
}

// MARK: - Supporting Views
struct ColorSwatch: View {
  let color: Color
  let label: String
  
  var body: some View {
    VStack(spacing: 2) {
      Circle()
        .fill(color)
        .frame(width: 20, height: 20)
        .overlay(
          Circle()
            .stroke(Color.secondary.opacity(0.3), lineWidth: 0.5)
        )
      
      Text(label)
        .font(.caption2)
        .foregroundColor(.secondary)
    }
  }
}

// MARK: - AppKit Color Well Wrapper
struct MacColorWell: NSViewRepresentable {
  @Binding var color: NSColor
  
  func makeNSView(context: Context) -> NSColorWell {
    let well = NSColorWell()
    well.color = color
    well.target = context.coordinator
    well.action = #selector(Coordinator.colorChanged(_:))
    return well
  }
  
  func updateNSView(_ nsView: NSColorWell, context: Context) {
    if nsView.color != color {
      nsView.color = color
    }
  }
  
  func makeCoordinator() -> Coordinator { Coordinator(self) }
  
  class Coordinator: NSObject {
    var parent: MacColorWell
    init(_ parent: MacColorWell) { self.parent = parent }
    
    @objc func colorChanged(_ sender: NSColorWell) {
      parent.color = sender.color
    }
  }
}

#Preview {
  AppearanceView(appearanceSettings: AppearanceSettings())
}
