import CCCustomPermissionServiceInterface
import SwiftUI

// MARK: - ApprovalToast

/// Compact toast-style approval UI that slides up from the bottom
public struct ApprovalToast: View {

  // MARK: Lifecycle

  public init(
    request: ApprovalRequest,
    showRiskLabel: Bool = true,
    queueCount: Int = 0,
    onApprove: @escaping () -> Void,
    onDeny: @escaping () -> Void
  ) {
    self.request = request
    self.showRiskLabel = showRiskLabel
    self.queueCount = queueCount
    self.onApprove = onApprove
    self.onDeny = onDeny
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
  let showRiskLabel: Bool
  let queueCount: Int
  let onApprove: () -> Void
  let onDeny: () -> Void

  // MARK: Private

  @State private var showDetails = false
  @FocusState private var isFocused: Bool

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

        if showRiskLabel {
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
    }
  }

  private var actionButtonsSection: some View {
    HStack(spacing: 8) {
      Button(action: {
        onDeny()
      }) {
        HStack(spacing: 4) {
          Text("Deny")
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
          onDeny: { }
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
          onDeny: { }
        )
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
      }
    }
    .previewDisplayName("Critical Risk Toast")
  }
}
#endif
