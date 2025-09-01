//
//  PermissionStatusView.swift
//  ClaudeCodeUI
//
//  Custom permission status monitoring component
//

import CCCustomPermissionServiceInterface
import SwiftUI

// MARK: - PermissionStatusView

/// A view that displays the current status of the custom permission service
struct PermissionStatusView: View {

  // MARK: Internal

  let customPermissionService: CustomPermissionService

  var body: some View {
    HStack(spacing: 4) {
      Image(systemName: autoApprove ? "shield.fill" : "shield")
        .foregroundColor(autoApprove ? .green : .orange)
        .font(.caption)

      Text(statusText)
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .help(helpText)
    .onReceive(customPermissionService.autoApprovePublisher) { newValue in
      autoApprove = newValue
    }
    .onAppear {
      Task { @MainActor in
        autoApprove = customPermissionService.autoApproveToolCalls
      }
    }
  }

  // MARK: Private

  @State private var autoApprove = false

  private var statusText: String {
    if autoApprove {
      "Auto-approve ON"
    } else {
      "Prompts enabled"
    }
  }

  private var helpText: String {
    if autoApprove {
      "Custom permission prompts are disabled - all tools are auto-approved"
    } else {
      "Custom permission prompts are enabled for tool requests"
    }
  }
}

// MARK: - DetailedPermissionStatusView

/// A more detailed permission status view for settings
struct DetailedPermissionStatusView: View {

  // MARK: Internal

  let customPermissionService: CustomPermissionService
  let globalPreferences: GlobalPreferencesStorage

  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      HStack {
        Image(systemName: "shield.checkerboard")
          .foregroundColor(.blue)
        Text("Permission System Status")
          .font(.headline)
        Spacer()
      }

      VStack(alignment: .leading, spacing: 4) {
        StatusRow(
          label: "Auto-approve all tools",
          isEnabled: autoApprove,
          color: autoApprove ? .green : .orange
        )

        StatusRow(
          label: "Auto-approve low-risk tools",
          isEnabled: autoApproveLowRisk && !autoApprove,
          color: (autoApproveLowRisk && !autoApprove) ? .green : .secondary,
          isDisabled: autoApprove
        )

        StatusRow(
          label: "Permission prompts",
          isEnabled: !autoApprove,
          color: !autoApprove ? .green : .secondary
        )

        HStack {
          Text("Timeout:")
            .font(.caption)
            .foregroundColor(.secondary)
          Text(globalPreferences.permissionTimeoutEnabled ? "\(Int(globalPreferences.permissionRequestTimeout))s" : "Disabled")
            .font(.caption)
            .foregroundColor(.secondary)

          Spacer()

          Text("Max concurrent:")
            .font(.caption)
            .foregroundColor(.secondary)
          Text("\(globalPreferences.maxConcurrentPermissionRequests)")
            .font(.caption)
            .foregroundColor(.secondary)
        }
      }
    }
    .padding(12)
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(8)
    .onReceive(customPermissionService.autoApprovePublisher) { newValue in
      autoApprove = newValue
    }
    .onAppear {
      Task { @MainActor in
        autoApprove = customPermissionService.autoApproveToolCalls
        autoApproveLowRisk = globalPreferences.autoApproveLowRisk
      }
    }
    .onChange(of: globalPreferences.autoApproveLowRisk) { _, newValue in
      autoApproveLowRisk = newValue
    }
  }

  // MARK: Private

  @State private var autoApprove = false
  @State private var autoApproveLowRisk = false

}

// MARK: - StatusRow

private struct StatusRow: View {
  let label: String
  let isEnabled: Bool
  let color: Color
  var isDisabled = false

  var body: some View {
    HStack {
      Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
        .foregroundColor(isDisabled ? .secondary : color)
        .font(.caption)

      Text(label)
        .font(.caption)
        .foregroundColor(isDisabled ? .secondary : .primary)

      if isDisabled {
        Text("(disabled)")
          .font(.caption2)
          .foregroundColor(.secondary)
          .italic()
      }

      Spacer()
    }
  }
}

// MARK: - CompactPermissionStatusView

/// A compact permission status indicator for menu bars or small spaces
struct CompactPermissionStatusView: View {
  let customPermissionService: CustomPermissionService
  @State private var autoApprove = false

  var body: some View {
    Button(action: { }) {
      Image(systemName: autoApprove ? "shield.fill" : "shield")
        .foregroundColor(autoApprove ? .green : .orange)
    }
    .buttonStyle(.plain)
    .help(autoApprove ? "Auto-approve is ON" : "Permission prompts are enabled")
    .onReceive(customPermissionService.autoApprovePublisher) { newValue in
      autoApprove = newValue
    }
    .onAppear {
      Task { @MainActor in
        autoApprove = customPermissionService.autoApproveToolCalls
      }
    }
  }
}

#if DEBUG
#Preview("Permission Status") {
  @Previewable @State var mockService = MockCustomPermissionService()
  @Previewable @State var mockGlobalPrefs = GlobalPreferencesStorage()

  VStack(spacing: 20) {
    PermissionStatusView(customPermissionService: mockService)

    DetailedPermissionStatusView(
      customPermissionService: mockService,
      globalPreferences: mockGlobalPrefs
    )

    CompactPermissionStatusView(customPermissionService: mockService)

    Button("Toggle Auto-approve") {
      mockService.autoApproveToolCalls.toggle()
    }
  }
  .padding()
  .frame(width: 400)
}
#endif
