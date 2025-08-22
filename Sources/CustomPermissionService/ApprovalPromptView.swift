import SwiftUI
import Combine
import CustomPermissionServiceInterface

/// SwiftUI view for displaying permission approval prompts
public struct ApprovalPromptView: View {
    @ObservedObject private var state: ApprovalPromptState
    @State private var showingDetails = false
    @State private var showingInputEditor = false
    
    public init(state: ApprovalPromptState) {
        self.state = state
    }
    
    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "shield.checkerboard")
                    .font(.largeTitle)
                    .foregroundColor(riskColor)
                
                VStack(alignment: .leading) {
                    Text("Permission Request")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(state.request.toolName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Risk level indicator
                RiskLevelBadge(riskLevel: state.request.context?.riskLevel ?? .medium)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
            .cornerRadius(8)
            
            // Main content
            VStack(alignment: .leading, spacing: 16) {
                // Description
                if let description = state.request.context?.description {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Description")
                            .font(.headline)
                        Text(description)
                            .font(.body)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Tool details
                DisclosureGroup("Tool Details", isExpanded: $showingDetails) {
                    VStack(alignment: .leading, spacing: 8) {
                        DetailRow(label: "Tool Name", value: state.request.toolName)
                        DetailRow(label: "Tool Use ID", value: state.request.toolUseId)
                        
                        if let context = state.request.context {
                            DetailRow(label: "Risk Level", value: context.riskLevel.displayName)
                            DetailRow(label: "Sensitive", value: context.isSensitive ? "Yes" : "No")
                            
                            if !context.affectedResources.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Affected Resources:")
                                        .font(.caption)
                                        .fontWeight(.medium)
                                    
                                    ForEach(context.affectedResources, id: \.self) { resource in
                                        Text("• \(resource)")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                        }
                    }
                    .padding(.top, 8)
                }
                
                // Input parameters
                if !state.request.input.isEmpty {
                    DisclosureGroup("Input Parameters", isExpanded: $showingInputEditor) {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(Array(state.request.input.keys.sorted()), id: \.self) { key in
                                if let originalValue = state.request.input[key] {
                                    InputParameterRow(
                                        key: key,
                                        value: originalValue,
                                        modifiedValue: Binding(
                                            get: { state.modifiedInput[key] ?? originalValue },
                                            set: { state.modifiedInput[key] = $0 }
                                        )
                                    )
                                }
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                
                // Warning for sensitive operations
                if state.request.context?.isSensitive == true {
                    HStack {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Text("This is a sensitive operation that may affect your system.")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(6)
                }
            }
            .padding()
            .background(Color(.textBackgroundColor))
            .cornerRadius(8)
            
            Spacer()
            
            // Denial reason (only shown when denying)
            if state.isProcessing && !state.denyReason.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Reason for denial:")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    TextField("Optional: Explain why this request was denied", text: $state.denyReason)
                        .textFieldStyle(.roundedBorder)
                }
            }
            
            // Action buttons
            HStack(spacing: 12) {
                Button("Deny") {
                    state.deny()
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(state.isProcessing)
                
                Spacer()
                
                Button("Approve") {
                    state.approve()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(state.isProcessing)
            }
            .padding(.horizontal)
        }
        .padding()
        .frame(width: 600, height: 500)
        .disabled(state.isProcessing)
        .overlay(
            Group {
                if state.isProcessing {
                    Color.black.opacity(0.3)
                        .overlay(
                            ProgressView("Processing...")
                                .padding()
                                .background(Color(.controlBackgroundColor))
                                .cornerRadius(8)
                        )
                }
            }
        )
    }
    
    private var riskColor: Color {
        switch state.request.context?.riskLevel {
        case .low: return .green
        case .medium: return .yellow
        case .high: return .orange
        case .critical: return .red
        case .none: return .blue
        }
    }
}

/// Badge showing risk level
private struct RiskLevelBadge: View {
    let riskLevel: RiskLevel
    
    var body: some View {
        Text(riskLevel.displayName)
            .font(.caption)
            .fontWeight(.medium)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(backgroundColor)
            .foregroundColor(foregroundColor)
            .cornerRadius(4)
    }
    
    private var backgroundColor: Color {
        switch riskLevel {
        case .low: return .green.opacity(0.2)
        case .medium: return .yellow.opacity(0.2)
        case .high: return .orange.opacity(0.2)
        case .critical: return .red.opacity(0.2)
        }
    }
    
    private var foregroundColor: Color {
        switch riskLevel {
        case .low: return .green
        case .medium: return .orange
        case .high: return .orange
        case .critical: return .red
        }
    }
}

/// Row for displaying detail information
private struct DetailRow: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text("\(label):")
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 100, alignment: .leading)
            
            Text(value)
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
        }
    }
}

/// Row for editing input parameters
private struct InputParameterRow: View {
    let key: String
    let value: SendableValue
    @Binding var modifiedValue: SendableValue
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(key)
                .font(.caption)
                .fontWeight(.medium)
            
            HStack {
                Text("Original:")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                
                Text(value.description)
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
                
                Spacer()
            }
            
            switch modifiedValue {
            case .string(let stringValue):
                TextField("Modified value", text: Binding(
                    get: { stringValue },
                    set: { modifiedValue = .string($0) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            case .integer(let intValue):
                TextField("Modified value", text: Binding(
                    get: { String(intValue) },
                    set: { modifiedValue = .integer(Int($0) ?? intValue) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            case .boolean(let boolValue):
                Toggle("", isOn: Binding(
                    get: { boolValue },
                    set: { modifiedValue = .boolean($0) }
                ))
                .toggleStyle(.switch)
            case .double(let doubleValue):
                TextField("Modified value", text: Binding(
                    get: { String(doubleValue) },
                    set: { modifiedValue = .double(Double($0) ?? doubleValue) }
                ))
                .textFieldStyle(.roundedBorder)
                .font(.caption)
            case .array(_), .dictionary(_), .null:
                Text(modifiedValue.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color(.controlBackgroundColor))
                    .cornerRadius(4)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Preview

#if DEBUG
struct ApprovalPromptView_Previews: PreviewProvider {
    @MainActor
    static var previews: some View {
        let context = ApprovalContext(
            description: "This tool will read and analyze the specified files to understand the code structure",
            riskLevel: .medium,
            isSensitive: false,
            affectedResources: ["src/main.swift", "src/utils.swift"]
        )
        
        let request = ApprovalRequest(
            toolName: "Read",
            input: [
                "file_path": .string("/Users/test/project/src/main.swift"),
                "limit": .integer(100),
                "recursive": .boolean(true)
            ],
            toolUseId: "read-123",
            context: context
        )
        
        let state = ApprovalPromptState(
            request: request,
            onApprove: { _ in },
            onDeny: { _ in }
        )
        
        ApprovalPromptView(state: state)
            .previewDisplayName("Medium Risk Request")
        
        // High risk example
        let highRiskContext = ApprovalContext(
            description: "This tool will execute shell commands that may modify your system",
            riskLevel: .critical,
            isSensitive: true,
            affectedResources: ["system files"]
        )
        
        let highRiskRequest = ApprovalRequest(
            toolName: "Bash",
            input: [
                "command": .string("rm -rf /tmp/cache"),
                "timeout": .integer(30)
            ],
            toolUseId: "bash-456",
            context: highRiskContext
        )
        
        let highRiskState = ApprovalPromptState(
            request: highRiskRequest,
            onApprove: { _ in },
            onDeny: { _ in }
        )
        
        ApprovalPromptView(state: highRiskState)
            .previewDisplayName("Critical Risk Request")
    }
}
#endif
