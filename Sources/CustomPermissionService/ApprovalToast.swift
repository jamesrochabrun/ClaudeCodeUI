import CCCustomPermissionServiceInterface
import SwiftUI
import Foundation

// MARK: - ApprovalToast

/// Compact toast-style approval UI that slides up from the bottom
public struct ApprovalToast: View {

  // MARK: Lifecycle

  public init(
    request: ApprovalRequest,
    showRiskData: Bool = true,
    queueCount: Int = 0,
    onApprove: @escaping () -> Void,
    onDeny: @escaping () -> Void,
    onDenyWithGuidance: @escaping (String) -> Void = { _ in },
    onCancel: @escaping () -> Void = { }
  ) {
    self.request = request
    self.showRiskData = showRiskData
    self.queueCount = queueCount
    self.onApprove = onApprove
    self.onDeny = onDeny
    self.onDenyWithGuidance = onDenyWithGuidance
    self.onCancel = onCancel
  }

  // MARK: Public

  public var body: some View {
    VStack(spacing: 0) {
      mainCompactView

      if showDetails {
        expandableDetailsView
      }
    }
    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
    .overlay(
      RoundedRectangle(cornerRadius: 12)
        .stroke(Color.primary.opacity(0.1), lineWidth: 1)
    )
    .onTapGesture {
      withAnimation(.easeInOut(duration: 0.2)) {
        showDetails.toggle()
      }
    }
    .focusable()
    .focused($isFocused)
    .onAppear {
      isFocused = true
    }
  }

  // MARK: Internal

  let request: ApprovalRequest
  let showRiskData: Bool
  let queueCount: Int
  let onApprove: () -> Void
  let onDeny: () -> Void
  let onDenyWithGuidance: (String) -> Void
  let onCancel: () -> Void

  // MARK: Private

  @State private var showDetails = false
  @State private var showGuidanceInput = false
  @State private var denyGuidance = ""
  @FocusState private var isFocused: Bool
  @FocusState private var isGuidanceFocused: Bool

  private var isEditTool: Bool {
    // Check if this is an Edit, MultiEdit, or Write tool
    ["Edit", "MultiEdit", "Write"].contains(request.toolName)
  }

  /// Extracts the most relevant parameter to display for this tool type
  private func extractRelevantParameter() -> (key: String, value: String)? {
    // Define tool-specific parameter priorities
    let parameterKey: String
    switch request.toolName.lowercased() {
    case "bash":
      parameterKey = "command"
    case "edit", "write", "read", "multiedit":
      parameterKey = "file_path"
    default:
      // For other tools, use the first available parameter
      guard let firstKey = request.input.keys.sorted().first else { return nil }
      parameterKey = firstKey
    }

    // Get the value for the selected parameter
    guard let value = request.input[parameterKey] else {
      // Fallback to first available parameter if the expected one doesn't exist
      guard let firstKey = request.input.keys.sorted().first,
            let firstValue = request.input[firstKey] else {
        return nil
      }
      return (key: firstKey, value: firstValue.description)
    }

    return (key: parameterKey, value: value.description)
  }

  private var mainCompactView: some View {
    HStack(spacing: 12) {
      riskIndicator
      toolInfoSection
      actionButtonsSection
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
  }

  private var riskIndicator: some View {
    Circle()
      .fill(riskColor)
      .frame(width: 8, height: 8)
  }

  private var toolInfoSection: some View {
    VStack(alignment: .leading, spacing: 2) {
      HStack {
        Text("Permission Request")
          .font(.system(size: 13, weight: .medium))

        if queueCount > 0 {
          Text("(\(queueCount) more pending)")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }

        Spacer()

        if showRiskData {
          Text(request.context?.riskLevel.displayName ?? "Unknown")
            .font(.system(size: 11))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(riskColor.opacity(0.2))
            .foregroundColor(riskColor)
            .cornerRadius(4)
        }
      }

      Text(request.toolName)
        .font(.system(size: 12))
        .foregroundColor(.secondary)

      // Show the most relevant parameter detail
      if let parameter = extractRelevantParameter() {
        parameterDetailView(value: parameter.value)
      }
    }
  }

  /// View for displaying the key parameter detail in collapsed state
  private func parameterDetailView(value: String) -> some View {
    Text(value)
      .font(.system(size: 11, design: .monospaced))
      .foregroundColor(.secondary.opacity(0.8))
      .lineLimit(3)
      .truncationMode(.tail)
      .padding(.top, 2)
  }

  private var actionButtonsSection: some View {
    HStack(spacing: 8) {
      Button(action: {
        if isEditTool {
          // For edit tools, show guidance input
          withAnimation(.easeInOut(duration: 0.2)) {
            showGuidanceInput = true
            showDetails = true
          }
          // Focus the guidance input field
          DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            isGuidanceFocused = true
          }
        } else {
          // For other tools, deny immediately
          onDeny()
        }
      }) {
        HStack(spacing: 4) {
          Text(isEditTool ? "Deny & Guide" : "Deny")
          Text("(esc)")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
        }
      }
      .buttonStyle(.bordered)
      .controlSize(.regular)
      .keyboardShortcut(.escape, modifiers: [])

      Button(action: {
        onApprove()
      }) {
        HStack(spacing: 4) {
          Text("Approve")
          Text("(⏎)")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
        }
      }
      .buttonStyle(.borderedProminent)
      .controlSize(.regular)
      .keyboardShortcut(.defaultAction)
    }
  }

  private var expandableDetailsView: some View {
    VStack(alignment: .leading, spacing: 8) {
      Divider()

      if let description = request.context?.description {
        Text(description)
          .font(.system(size: 12))
          .foregroundColor(.secondary)
      }

      if !request.input.isEmpty {
        parametersSection
      }

      // Show guidance input for Edit tools when denying
      if showGuidanceInput && isEditTool {
        guidanceInputSection
      }
    }
    .padding(.horizontal, 16)
    .padding(.bottom, 12)
  }

  private var parametersSection: some View {
    VStack(alignment: .leading, spacing: 4) {
      Text("Parameters:")
        .font(.system(size: 11, weight: .medium))

      ForEach(Array(request.input.keys.prefix(3).sorted()), id: \.self) { key in
        HStack {
          Text("\(key):")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
          Text(request.input[key]?.description ?? "")
            .font(.system(size: 10))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .truncationMode(.tail)
        }
      }

      if request.input.count > 3 {
        Text("... and \(request.input.count - 3) more")
          .font(.system(size: 10))
          .foregroundColor(Color.secondary)
      }
    }
  }

  private var guidanceInputSection: some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Tell Claude what to do instead:")
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(.secondary)

      HStack {
        TextField("e.g., Create a new file instead, or Use a different approach...", text: $denyGuidance)
          .textFieldStyle(.roundedBorder)
          .font(.system(size: 12))
          .focused($isGuidanceFocused)
          .onSubmit {
            // Submit the denial with guidance
            let guidance = denyGuidance.isEmpty ?
              "User denied the request but provided no specific guidance" :
              denyGuidance
            onDenyWithGuidance(guidance)
          }

        Button("Cancel") {
          onCancel()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)

        Button("Send") {
          let guidance = denyGuidance.isEmpty ?
            "User denied the request but provided no specific guidance" :
            denyGuidance
          onDenyWithGuidance(guidance)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
      }
    }
  }

  private var riskColor: Color {
    switch request.context?.riskLevel {
    case .low: .green
    case .medium: .yellow
    case .high: .orange
    case .critical: .red
    case .none: .blue
    }
  }
}

// MARK: - ToastContainer

/// Container for showing toast with animation
public struct ToastContainer: View {

  // MARK: Lifecycle

  public init(
    isPresented: Binding<Bool>,
    @ViewBuilder content: () -> some View
  ) {
    _isPresented = isPresented
    self.content = AnyView(content())
  }

  // MARK: Public

  public var body: some View {
    GeometryReader { _ in
      VStack {
        Spacer()

        if isPresented {
          content
            .padding(.horizontal, 16)
            .padding(.bottom, 20)
            .transition(.asymmetric(
              insertion: .move(edge: .bottom).combined(with: .opacity),
              removal: .move(edge: .bottom).combined(with: .opacity)
            ))
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: isPresented)
        }
      }
    }
    .allowsHitTesting(isPresented)
  }

  // MARK: Internal

  @Binding var isPresented: Bool

  let content: AnyView

}

// MARK: - Preview

#if DEBUG
struct ApprovalToast_Previews: PreviewProvider {
  static var previews: some View {
    ZStack {
      Color.gray.opacity(0.1)
        .ignoresSafeArea()

      VStack {
        Spacer()

        ApprovalToast(
          request: ApprovalRequest(
            toolName: "LS",
            input: [
              "path": .string("/Users/test/Desktop"),
              "ignore": .array([.string("*.tmp")]),
            ],
            toolUseId: "ls-123",
            context: ApprovalContext(
              description: "List files and directories in the specified path",
              riskLevel: .low,
              isSensitive: false,
              affectedResources: ["/Users/test/Desktop"]
            )
          ),
          onApprove: { },
          onDeny: { },
          onCancel: { }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
      }
    }
    .previewDisplayName("Low Risk Toast")

    ZStack {
      Color.gray.opacity(0.1)
        .ignoresSafeArea()

      VStack {
        Spacer()

        ApprovalToast(
          request: ApprovalRequest(
            toolName: "Bash",
            input: [
              "command": .string("rm -rf /tmp/cache"),
              "timeout": .integer(30),
            ],
            toolUseId: "bash-456",
            context: ApprovalContext(
              description: "Execute shell command that may modify system files",
              riskLevel: .critical,
              isSensitive: true,
              affectedResources: ["/tmp/cache"]
            )
          ),
          onApprove: { },
          onDeny: { },
          onCancel: { }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
      }
    }
    .previewDisplayName("Critical Risk Toast")

    ZStack {
      Color.gray.opacity(0.1)
        .ignoresSafeArea()

      VStack {
        Spacer()

        ApprovalToast(
          request: ApprovalRequest(
            toolName: "Edit",
            input: [
              "file_path": .string("/Users/test/main.swift"),
              "old_string": .string("func test()"),
              "new_string": .string("func testNew()"),
            ],
            toolUseId: "edit-789",
            context: ApprovalContext(
              description: "Edit file to rename function",
              riskLevel: .medium,
              isSensitive: false,
              affectedResources: ["/Users/test/main.swift"]
            )
          ),
          onApprove: { },
          onDeny: { },
          onDenyWithGuidance: { guidance in
            print("Guidance: \(guidance)")
          },
          onCancel: {
            print("Cancelled - Stream will be interrupted")
          }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
      }
    }
    .previewDisplayName("Edit Tool with Deny & Guide")
  }
}
#endif
