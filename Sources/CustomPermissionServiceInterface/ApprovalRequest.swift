import Foundation
import SwiftUI
import Combine
import ClaudeCodeSDK

/// A Sendable-compatible type that can hold various JSON values
public enum SendableValue: Codable, Sendable {
  case string(String)
  case integer(Int)
  case double(Double)
  case boolean(Bool)
  case array([SendableValue])
  case dictionary([String: SendableValue])
  case null
  
  /// Convert to Any for compatibility with existing APIs
  public var anyValue: Any {
    switch self {
    case .string(let value): return value
    case .integer(let value): return value
    case .double(let value): return value
    case .boolean(let value): return value
    case .array(let value): return value.map { $0.anyValue }
    case .dictionary(let value): return value.mapValues { $0.anyValue }
    case .null: return NSNull()
    }
  }
  
  /// String description for UI display
  public var description: String {
    switch self {
    case .string(let value): return value
    case .integer(let value): return String(value)
    case .double(let value): return String(value)
    case .boolean(let value): return String(value)
    case .array(let value): return "[\(value.map { $0.description }.joined(separator: ", "))]"
    case .dictionary(let value): return "{\(value.map { "\($0.key): \($0.value.description)" }.joined(separator: ", "))}"
    case .null: return "null"
    }
  }
  
  /// Create from Any value
  public static func from(_ value: Any) -> SendableValue {
    switch value {
    case let string as String:
      return .string(string)
    case let int as Int:
      return .integer(int)
    case let double as Double:
      return .double(double)
    case let bool as Bool:
      return .boolean(bool)
    case let array as [Any]:
      return .array(array.map { SendableValue.from($0) })
    case let dict as [String: Any]:
      return .dictionary(dict.mapValues { SendableValue.from($0) })
    case is NSNull, Optional<Any>.none:
      return .null
    default:
      // Fallback to string representation for unknown types
      return .string(String(describing: value))
    }
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.singleValueContainer()
    
    if let string = try? container.decode(String.self) {
      self = .string(string)
    } else if let int = try? container.decode(Int.self) {
      self = .integer(int)
    } else if let double = try? container.decode(Double.self) {
      self = .double(double)
    } else if let bool = try? container.decode(Bool.self) {
      self = .boolean(bool)
    } else if let array = try? container.decode([SendableValue].self) {
      self = .array(array)
    } else if let dict = try? container.decode([String: SendableValue].self) {
      self = .dictionary(dict)
    } else if container.decodeNil() {
      self = .null
    } else {
      throw DecodingError.dataCorruptedError(in: container, debugDescription: "Cannot decode SendableValue")
    }
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.singleValueContainer()
    
    switch self {
    case .string(let value):
      try container.encode(value)
    case .integer(let value):
      try container.encode(value)
    case .double(let value):
      try container.encode(value)
    case .boolean(let value):
      try container.encode(value)
    case .array(let value):
      try container.encode(value)
    case .dictionary(let value):
      try container.encode(value)
    case .null:
      try container.encodeNil()
    }
  }
}

/// Represents a request for permission approval, matching the structure expected by Claude Code SDK
public struct ApprovalRequest: Codable, Sendable {
  /// The name of the tool being requested
  public let toolName: String
  
  /// The input parameters for the tool (Sendable-compatible)
  public let input: [String: SendableValue]
  
  /// Unique identifier for this tool use request
  public let toolUseId: String
  
  /// Additional context information about the request
  public let context: ApprovalContext?
  
  private enum CodingKeys: String, CodingKey {
    case toolName = "tool_name"
    case input
    case toolUseId = "tool_use_id"
    case context
  }
  
  public init(toolName: String, anyInput: [String: Any], toolUseId: String, context: ApprovalContext? = nil) {
    self.toolName = toolName
    self.input = anyInput.mapValues { SendableValue.from($0) }
    self.toolUseId = toolUseId
    self.context = context
  }
  
  public init(toolName: String, input: [String: SendableValue], toolUseId: String, context: ApprovalContext? = nil) {
    self.toolName = toolName
    self.input = input
    self.toolUseId = toolUseId
    self.context = context
  }
  
  /// Get input as [String: Any] for compatibility
  public var inputAsAny: [String: Any] {
    return input.mapValues { $0.anyValue }
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    toolName = try container.decode(String.self, forKey: .toolName)
    toolUseId = try container.decode(String.self, forKey: .toolUseId)
    context = try container.decodeIfPresent(ApprovalContext.self, forKey: .context)
    input = try container.decode([String: SendableValue].self, forKey: .input)
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    
    try container.encode(toolName, forKey: .toolName)
    try container.encode(toolUseId, forKey: .toolUseId)
    try container.encodeIfPresent(context, forKey: .context)
    try container.encode(input, forKey: .input)
  }
}

/// Additional context information for approval requests
public struct ApprovalContext: Codable, Sendable {
  /// Description of what the tool will do
  public let description: String?
  
  /// Risk level assessment
  public let riskLevel: RiskLevel
  
  /// Whether this is a sensitive operation
  public let isSensitive: Bool
  
  /// Files or resources that will be affected
  public let affectedResources: [String]
  
  public init(description: String? = nil, riskLevel: RiskLevel = .medium, isSensitive: Bool = false, affectedResources: [String] = []) {
    self.description = description
    self.riskLevel = riskLevel
    self.isSensitive = isSensitive
    self.affectedResources = affectedResources
  }
}

/// Risk level for tool operations
public enum RiskLevel: String, Codable, CaseIterable, Sendable {
  case low = "low"
  case medium = "medium"
  case high = "high"
  case critical = "critical"
  
  public var displayName: String {
    switch self {
    case .low: return "Low Risk"
    case .medium: return "Medium Risk"
    case .high: return "High Risk"
    case .critical: return "Critical Risk"
    }
  }
  
  public var color: String {
    switch self {
    case .low: return "green"
    case .medium: return "yellow"
    case .high: return "orange"
    case .critical: return "red"
    }
  }
}

/// State management for approval prompt UI
@MainActor
public final class ApprovalPromptState: ObservableObject {
  public let request: ApprovalRequest
  public let onApprove: ([String: Any]?) async -> Void
  public let onDeny: (String) async -> Void
  
  @Published public var modifiedInput: [String: SendableValue]
  @Published public var denyReason: String = ""
  @Published public var isProcessing: Bool = false
  
  public init(
    request: ApprovalRequest,
    onApprove: @escaping ([String: Any]?) async -> Void,
    onDeny: @escaping (String) async -> Void
  ) {
    self.request = request
    self.onApprove = onApprove
    self.onDeny = onDeny
    self.modifiedInput = request.input
  }
  
  public func approve() {
    isProcessing = true
    let convertedInput = modifiedInput.mapValues { $0.anyValue }
    Task {
      await onApprove(convertedInput)
    }
  }
  
  public func deny() {
    isProcessing = true
    let reason = denyReason.isEmpty ? "Denied by user" : denyReason
    Task {
      await onDeny(reason)
    }
  }
}

/// Represents the response to an approval request
public struct ApprovalResponse: Codable, Sendable {
  /// Whether the request was approved or denied
  public let behavior: ApprovalBehavior
  
  /// Updated input parameters (if modified during approval)
  public let updatedInput: [String: SendableValue]?
  
  /// Message explaining the decision
  public let message: String?
  
  public init(behavior: ApprovalBehavior, updatedInput: [String: Any]? = nil, message: String? = nil) {
    self.behavior = behavior
    self.updatedInput = updatedInput?.mapValues { SendableValue.from($0) }
    self.message = message
  }
  
  public init(behavior: ApprovalBehavior, sendableUpdatedInput: [String: SendableValue]? = nil, message: String? = nil) {
    self.behavior = behavior
    self.updatedInput = sendableUpdatedInput
    self.message = message
  }
  
  /// Get updatedInput as [String: Any] for compatibility
  public var updatedInputAsAny: [String: Any]? {
    return updatedInput?.mapValues { $0.anyValue }
  }
  
  public init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    
    behavior = try container.decode(ApprovalBehavior.self, forKey: .behavior)
    message = try container.decodeIfPresent(String.self, forKey: .message)
    updatedInput = try container.decodeIfPresent([String: SendableValue].self, forKey: .updatedInput)
  }
  
  public func encode(to encoder: Encoder) throws {
    var container = encoder.container(keyedBy: CodingKeys.self)
    
    try container.encode(behavior, forKey: .behavior)
    try container.encodeIfPresent(message, forKey: .message)
    try container.encodeIfPresent(updatedInput, forKey: .updatedInput)
  }
  
  private enum CodingKeys: String, CodingKey {
    case behavior
    case updatedInput
    case message
  }
}

/// Approval behavior options
public enum ApprovalBehavior: String, Codable, Sendable {
  case allow = "allow"
  case deny = "deny"
}

