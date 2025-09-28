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
  @State private var textFormatter: TextFormatter
  
  @Environment(\.colorScheme) private var colorScheme
  
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
    
    // Initialize TextFormatter with the plan content
    let formatter = TextFormatter(projectRoot: nil)
    formatter.ingest(delta: planContent)
    _textFormatter = State(initialValue: formatter)
  }
  
  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack {
        Text(" Here is Claude's plan:  ")
          .font(.system(size: 14, weight: .medium))
        
        Spacer()
        
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
        
        Button(action: onDismiss) {
          Image(systemName: "xmark.circle.fill")
            .font(.system(size: 16))
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 16)
      .padding(.vertical, 12)
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
              fontSize: 14,
              colorScheme: colorScheme
            )
          }
          .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxHeight: 400)
        .background(contentBackground)
        
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
          .padding(16)
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
          .padding(16)
          .background(actionButtonBackground)
        }
      }
    }
    .background(Color(NSColor.windowBackgroundColor))
    .cornerRadius(12)
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(borderColor, lineWidth: 1)
    )
    .shadow(color: .black.opacity(0.1), radius: 4, x: 0, y: 2)
    .frame(maxWidth: 700)
    .animation(.easeInOut(duration: 0.2), value: isExpanded)
    .animation(.easeInOut(duration: 0.2), value: showingDenyFeedback)
  }
  
  // MARK: - Computed Properties
  
  private var headerBackground: SwiftUI.Color {
    colorScheme == .dark
    ? Color(white: 0.15)
    : Color(white: 0.95)
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
    colorScheme == .dark
    ? Color(white: 0.25)
    : Color(white: 0.85)
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
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
      
    case .codeBlock(let code):
      CodeBlockContentView(code: code, role: .assistant)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
      
    case .table(let table):
      TableContentView(table: table, role: .assistant)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
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

/// Toast wrapper for PlanApprovalView
public struct PlanApprovalToast: View {
  @Binding var planApproval: PlanApprovalData?
  
  public init(planApproval: Binding<PlanApprovalData?>) {
    _planApproval = planApproval
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
    
    I'll create a demo Fibonacci function in your Swift project with the following approach:
    
    ### Implementation Steps:
    
    1. **Create a new MathUtilities file** in Sources/ClaudeCodeCore/Utils/
    2. **Implement Fibonacci function** with:
       - Iterative approach for efficiency
       - Memoization using @Observable for caching
       - Support for both single value and sequence generation
    3. **Add comprehensive unit tests** in the Tests directory
    4. **Create usage examples** demonstrating the function
    
    ### Code Structure:
    
    ```swift
    // MathUtilities.swift
    @Observable
    class FibonacciCalculator {
      private var cache: [Int: Int] = [0: 0, 1: 1]
    
      func fibonacci(_ n: Int) -> Int {
        if let cached = cache[n] {
          return cached
        }
    
        var a = 0
        var b = 1
    
        for i in 2...n {
          let temp = a + b
          a = b
          b = temp
          cache[i] = b
        }
    
        return b
      }
    
      func sequence(upTo n: Int) -> [Int] {
        (0...n).map { fibonacci($0) }
      }
    }
    ```
    
    This will demonstrate a complete feature implementation with proper Swift patterns following your codebase conventions.
    """,
    onApprove: { print("Approved") },
    onApproveWithAutoAccept: { print("Approved with auto-accept") },
    onDeny: { feedback in print("Denied with feedback: \(feedback ?? "none")") },
    onDismiss: { print("Dismissed") }
  )
  .padding()
  .frame(width: 800)
  .frame(height: 500)
  .background(Color(NSColor.windowBackgroundColor))
}
