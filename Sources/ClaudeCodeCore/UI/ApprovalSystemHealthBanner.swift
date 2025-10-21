//
//  ApprovalSystemHealthBanner.swift
//  ClaudeCodeUI
//
//  Created on Recovery system implementation
//

import SwiftUI
import CCCustomPermissionServiceInterface

/// Banner that displays when the approval system is unhealthy and offers recovery options
struct ApprovalSystemHealthBanner: View {
  let permissionService: CustomPermissionService
  let approvalBridge: ApprovalBridge?
  @State private var isExpanded = false
  @Environment(\.colorScheme) private var colorScheme

  var body: some View {
    if !permissionService.isHealthy {
      VStack(alignment: .leading, spacing: 12) {
        // Header with icon and title
        HStack(spacing: 12) {
          Image(systemName: "exclamationmark.triangle.fill")
            .font(.system(size: 18))
            .foregroundStyle(.orange)

          VStack(alignment: .leading, spacing: 4) {
            Text("Approval System Issue Detected")
              .font(.system(size: 14, weight: .semibold))
              .foregroundStyle(.primary)

            Text("The approval system may be stuck or experiencing errors")
              .font(.system(size: 12))
              .foregroundStyle(.secondary)
          }

          Spacer()

          // Toggle details button
          Button(action: {
            withAnimation(.spring(response: 0.3)) {
              isExpanded.toggle()
            }
          }) {
            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(.secondary)
          }
          .buttonStyle(.plain)
        }

        // Expanded details and recovery options
        if isExpanded {
          Divider()

          VStack(alignment: .leading, spacing: 8) {
            Text("This can happen when:")
              .font(.system(size: 12, weight: .medium))
              .foregroundStyle(.primary)

            VStack(alignment: .leading, spacing: 4) {
              bulletPoint("An MCP tool server crashed or lost connection")
              bulletPoint("Approval requests timed out")
              bulletPoint("The system entered an unrecoverable state")
            }
            .font(.system(size: 11))
            .foregroundStyle(.secondary)

            Divider()
              .padding(.vertical, 4)

            HStack(spacing: 12) {
              Button(action: resetApprovalSystem) {
                HStack(spacing: 6) {
                  Image(systemName: "arrow.clockwise")
                  Text("Reset Approval System")
                }
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.orange)
                .cornerRadius(6)
              }
              .buttonStyle(.plain)

              Text("This will clear all pending approval requests")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

              Spacer()
            }
          }
        }
      }
      .padding(16)
      .background(backgroundColor)
      .cornerRadius(8)
      .overlay(
        RoundedRectangle(cornerRadius: 8)
          .stroke(Color.orange.opacity(0.5), lineWidth: 1)
      )
      .padding(.horizontal, 16)
      .padding(.vertical, 8)
      .transition(.move(edge: .top).combined(with: .opacity))
    }
  }

  private func bulletPoint(_ text: String) -> some View {
    HStack(alignment: .top, spacing: 6) {
      Text("•")
        .font(.system(size: 11))
      Text(text)
    }
  }

  private var backgroundColor: Color {
    colorScheme == .dark
      ? Color.orange.opacity(0.15)
      : Color.orange.opacity(0.08)
  }

  private func resetApprovalSystem() {
    // Reset both the permission service and approval bridge
    permissionService.resetState()
    approvalBridge?.resetState()

    // Provide haptic feedback
    #if os(macOS)
    NSHapticFeedbackManager.defaultPerformer.perform(
      .alignment,
      performanceTime: .now
    )
    #endif

    // Auto-collapse after reset
    withAnimation(.spring(response: 0.3).delay(0.5)) {
      isExpanded = false
    }
  }
}

// MARK: - Preview

#Preview {
  @Previewable @State var mockService = MockCustomPermissionService()

  VStack {
    ApprovalSystemHealthBanner(
      permissionService: mockService,
      approvalBridge: nil
    )

    Spacer()
  }
  .padding()
  .onAppear {
    mockService.shouldThrowError = true  // Make it unhealthy for preview
  }
}
