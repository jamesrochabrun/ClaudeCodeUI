//
//  PlanApprovalView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 2025.
//

import SwiftUI
import Down

/// A view that displays a plan for approval when exiting plan mode
public struct PlanApprovalView: View {
  let planContent: String
  let onApprove: () -> Void
  let onApproveWithAutoAccept: () -> Void
  let onDeny: (String?) -> Void
  let onDismiss: () -> Void

  @State private var showingDenyFeedback = false
  @State private var denyFeedback = ""
  @State private var isExpanded = true

  public init(
    planContent: String,
    onApprove: @escaping () -> Void,
    onApproveWithAutoAccept: @escaping () -> Void,
    onDeny: @escaping (String?) -> Void,
    onDismiss: @escaping () -> Void
  ) {
    self.planContent = planContent
    self.onApprove = onApprove
    self.onApproveWithAutoAccept = onApproveWithAutoAccept
    self.onDeny = onDeny
    self.onDismiss = onDismiss
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header
      HStack {
        Image(systemName: "doc.plaintext")
          .font(.title2)
          .foregroundColor(.blue)

        Text("Plan Approval Required")
          .font(.headline)

        Spacer()

        Button(action: {
          withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
          }
        }) {
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption)
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)

        Button(action: onDismiss) {
          Image(systemName: "xmark.circle.fill")
            .font(.title2)
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
      }

      if isExpanded {
        // Plan content (markdown)
        ScrollView {
          VStack(alignment: .leading, spacing: 8) {
            if let attributedString = try? Down(markdownString: planContent).toAttributedString() {
              Text(AttributedString(attributedString))
                .textSelection(.enabled)
            } else {
              Text(planContent)
                .font(.system(.body, design: .monospaced))
                .textSelection(.enabled)
            }
          }
          .padding(.vertical, 8)
        }
        .frame(maxHeight: 300)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(6)

        // Action buttons
        if showingDenyFeedback {
          // Deny feedback UI
          VStack(alignment: .leading, spacing: 8) {
            Text("Provide feedback (optional):")
              .font(.caption)
              .foregroundColor(.secondary)

            TextEditor(text: $denyFeedback)
              .font(.system(.body, design: .default))
              .frame(height: 60)
              .scrollContentBackground(.hidden)
              .background(Color(NSColor.controlBackgroundColor))
              .cornerRadius(4)
              .overlay(
                RoundedRectangle(cornerRadius: 4)
                  .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
              )

            HStack(spacing: 8) {
              Button("Cancel") {
                withAnimation {
                  showingDenyFeedback = false
                  denyFeedback = ""
                }
              }
              .buttonStyle(.plain)
              .foregroundColor(.secondary)

              Button("Send Feedback") {
                onDeny(denyFeedback.isEmpty ? nil : denyFeedback)
                onDismiss()
              }
              .buttonStyle(.borderedProminent)
              .controlSize(.small)
            }
          }
          .transition(.opacity.combined(with: .move(edge: .top)))
        } else {
          // Main action buttons
          HStack(spacing: 8) {
            Button("Deny") {
              withAnimation {
                showingDenyFeedback = true
              }
            }
            .buttonStyle(.plain)
            .foregroundColor(.red)

            Spacer()

            Button("Approve") {
              onApprove()
              onDismiss()
            }
            .buttonStyle(.bordered)
            .controlSize(.regular)

            Button("Approve & Auto-accept edits") {
              onApproveWithAutoAccept()
              onDismiss()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.regular)
          }
        }
      }
    }
    .padding()
    .background(Color(NSColor.windowBackgroundColor))
    .cornerRadius(12)
    .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
    .frame(maxWidth: 600)
    .animation(.easeInOut(duration: 0.2), value: isExpanded)
    .animation(.easeInOut(duration: 0.2), value: showingDenyFeedback)
  }
}

/// Toast wrapper for PlanApprovalView
public struct PlanApprovalToast: View {
  @Binding var planApproval: PlanApprovalData?

  public init(planApproval: Binding<PlanApprovalData?>) {
    self._planApproval = planApproval
  }

  public var body: some View {
    VStack {
      if let approval = planApproval {
        PlanApprovalView(
          planContent: approval.planContent,
          onApprove: approval.onApprove,
          onApproveWithAutoAccept: approval.onApproveWithAutoAccept,
          onDeny: approval.onDeny,
          onDismiss: {
            planApproval = nil
          }
        )
        .transition(.asymmetric(
          insertion: .move(edge: .top).combined(with: .opacity),
          removal: .move(edge: .top).combined(with: .opacity)
        ))
      }

      Spacer()
    }
    .padding()
    .animation(.spring(response: 0.3, dampingFraction: 0.8), value: planApproval != nil)
  }
}

/// Data model for plan approval
public struct PlanApprovalData: Identifiable {
  public let id = UUID()
  public let planContent: String
  public let onApprove: () -> Void
  public let onApproveWithAutoAccept: () -> Void
  public let onDeny: (String?) -> Void

  public init(
    planContent: String,
    onApprove: @escaping () -> Void,
    onApproveWithAutoAccept: @escaping () -> Void,
    onDeny: @escaping (String?) -> Void
  ) {
    self.planContent = planContent
    self.onApprove = onApprove
    self.onApproveWithAutoAccept = onApproveWithAutoAccept
    self.onDeny = onDeny
  }
}

#Preview {
  PlanApprovalView(
    planContent: """
    ## Implementation Plan

    1. **Create permission mode enum**
       - Define states: default, plan, acceptEdits, bypassPermissions

    2. **Add UI components**
       - Create mode indicator
       - Add keyboard shortcut handler

    3. **Integrate with Claude SDK**
       - Pass permission mode in options
       - Handle mode-specific behaviors

    This plan will enable full permission mode support in the application.
    """,
    onApprove: { print("Approved") },
    onApproveWithAutoAccept: { print("Approved with auto-accept") },
    onDeny: { feedback in print("Denied with feedback: \(feedback ?? "none")") },
    onDismiss: { print("Dismissed") }
  )
  .padding()
  .frame(width: 700)
}