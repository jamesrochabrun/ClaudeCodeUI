//
//  InlinePlanApprovalView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 2025.
//

import SwiftUI
import Down
import AppKit

/// A view that displays a plan for approval inline within a chat message
public struct InlinePlanApprovalView: View {
  let messageId: UUID
  let planContent: String
  let viewModel: ChatViewModel
  let isResolved: Bool
  let approvalStatus: PlanApprovalStatus?

  @State private var showingDenyFeedback = false
  @State private var denyFeedback = ""
  @State private var isExpanded = true
  @State private var textFormatter: TextFormatter

  @Environment(\.colorScheme) private var colorScheme

  public init(
    messageId: UUID,
    planContent: String,
    viewModel: ChatViewModel,
    isResolved: Bool = false,
    approvalStatus: PlanApprovalStatus? = nil
  ) {
    self.messageId = messageId
    self.planContent = planContent
    self.viewModel = viewModel
    self.isResolved = isResolved
    self.approvalStatus = approvalStatus

    // Initialize TextFormatter with the plan content
    let formatter = TextFormatter(projectRoot: nil)
    formatter.ingest(delta: planContent)
    _textFormatter = State(initialValue: formatter)
  }

  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack {
        Image(systemName: headerIcon)
          .font(.system(size: 14))
          .foregroundColor(headerColor)

        Text(headerText)
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.primary)

        Spacer()

        // Copy button with feedback
        CopyButton(textToCopy: planContent)

        Button(action: {
          withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
          }
        }) {
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(headerBackground)

      // Divider
      Rectangle()
        .fill(borderColor)
        .frame(height: 1)

      if isExpanded {
        // Plan content with proper formatting
        ScrollView {
          VStack(alignment: .leading, spacing: 0) {
            PlanContentView(
              textFormatter: textFormatter,
              fontSize: 13,
              colorScheme: colorScheme
            )
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 350)
        .background(contentBackground)

        // Only show actions if not resolved
        if !isResolved {
          // Divider before action buttons
          Rectangle()
            .fill(borderColor)
            .frame(height: 1)

          // Action buttons
          if showingDenyFeedback {
            // Deny feedback UI
            VStack(alignment: .leading, spacing: 8) {
              Text("Provide feedback (optional):")
                .font(.caption)
                .foregroundColor(.secondary)

              TextEditor(text: $denyFeedback)
                .font(.system(.body, design: .default))
                .frame(height: 50)
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
                  handleDeny(feedback: denyFeedback.isEmpty ? nil : denyFeedback)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
              }
            }
            .padding(12)
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
              .font(.system(size: 13))

              Spacer()

              Button("Approve") {
                handleApprove()
              }
              .buttonStyle(.bordered)
              .controlSize(.small)

              Button("Approve & Auto-accept") {
                handleApproveWithAutoAccept()
              }
              .buttonStyle(.borderedProminent)
              .controlSize(.small)
            }
            .padding(12)
            .background(actionButtonBackground)
          }
        }
      }
    }
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(10)
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(borderColor, lineWidth: 1)
    )
    .animation(.easeInOut(duration: 0.2), value: isExpanded)
    .animation(.easeInOut(duration: 0.2), value: showingDenyFeedback)
  }

  // MARK: - Computed Properties

  private var headerIcon: String {
    if isResolved {
      switch approvalStatus {
      case .approved, .approvedWithAutoAccept:
        return "checkmark.circle.fill"
      case .denied:
        return "xmark.circle.fill"
      default:
        return "doc.plaintext"
      }
    }
    return "doc.plaintext"
  }

  private var headerColor: SwiftUI.Color {
    if isResolved {
      switch approvalStatus {
      case .approved, .approvedWithAutoAccept:
        return .green
      case .denied:
        return .red
      default:
        return .blue
      }
    }
    return .blue
  }

  private var headerText: String {
    if isResolved {
      switch approvalStatus {
      case .approved:
        return "Plan Approved"
      case .approvedWithAutoAccept:
        return "Plan Approved (Auto-accept enabled)"
      case .denied:
        return "Plan Denied"
      default:
        return "Plan"
      }
    }
    return "Plan Approval Required"
  }

  private var headerBackground: SwiftUI.Color {
    let baseColor = isResolved ? headerColor.opacity(0.15) : Color.blue.opacity(0.1)
    return colorScheme == .dark ? baseColor : baseColor.opacity(0.8)
  }

  private var contentBackground: SwiftUI.Color {
    colorScheme == .dark
      ? Color(NSColor.controlBackgroundColor)
      : Color.white
  }

  private var actionButtonBackground: SwiftUI.Color {
    colorScheme == .dark
      ? Color(white: 0.12)
      : Color(white: 0.98)
  }

  private var borderColor: SwiftUI.Color {
    if isResolved {
      return headerColor.opacity(0.3)
    }
    return colorScheme == .dark
      ? Color(white: 0.25)
      : Color(white: 0.85)
  }

  // MARK: - Action Handlers

  private func handleApprove() {
    // Update message status
    viewModel.updatePlanApprovalStatus(messageId: messageId, status: .approved)

    // Switch to default mode and continue
    viewModel.permissionMode = .default
    viewModel.sendMessage("Plan approved, continuing...")
  }

  private func handleApproveWithAutoAccept() {
    // Update message status
    viewModel.updatePlanApprovalStatus(messageId: messageId, status: .approvedWithAutoAccept)

    // Switch to acceptEdits mode for this turn
    viewModel.permissionMode = .acceptEdits
    viewModel.sendMessage("Plan approved with auto-accept, continuing...")
  }

  private func handleDeny(feedback: String?) {
    // Update message status
    viewModel.updatePlanApprovalStatus(messageId: messageId, status: .denied)

    // Switch to default mode and send feedback
    viewModel.permissionMode = .default
    let message = feedback ?? "Plan denied. Please provide an alternative approach."
    viewModel.sendMessage(message)
  }
}

/// A view that renders plan content with proper formatting
private struct PlanContentView: View {
  let textFormatter: TextFormatter
  let fontSize: Double
  let colorScheme: ColorScheme

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      ForEach(textFormatter.elements) { element in
        elementView(element)
      }
    }
  }

  @ViewBuilder
  private func elementView(_ element: TextFormatter.Element) -> some View {
    switch element {
    case .text(let text):
      let attributedText = markdown(for: text)
      Text(attributedText)
        .textSelection(.enabled)
        .padding(.horizontal, 14)
        .padding(.vertical, 6)

    case .codeBlock(let code):
      CodeBlockContentView(code: code, role: .assistant)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)

    case .table(let table):
      TableContentView(table: table, role: .assistant)
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
    }
  }

  private func markdown(for text: TextFormatter.Element.TextElement) -> AttributedString {
    let markDown = Down(markdownString: text.text)
    do {
      let style = MarkdownStyle(colorScheme: colorScheme)
      let attributedString = try markDown.toAttributedString(using: style)
      return AttributedString(attributedString.trimmedAttributedString())
    } catch {
      return AttributedString(text.text)
    }
  }
}
