import Foundation
import MCP
import Logging

// MARK: - MCP Server for Approval Prompts

/// Swift MCP server that handles approval prompts for Claude Code tools
@main
struct ApprovalMCPServer {
    static func main() async {
        // Configure logging
        LoggingSystem.bootstrap { label in
            var handler = StreamLogHandler.standardError(label: label)
            handler.logLevel = .info
            return handler
        }
        
        let logger = Logger(label: "com.claudecodeui.approval-mcp-server")
        
        do {
            // Create the approval server
            let approvalServer = ApprovalServer(logger: logger)
            
            // Start the server
            try await approvalServer.run()
        } catch {
            logger.error("Failed to start MCP server: \(error)")
            exit(1)
        }
    }
}

// MARK: - Approval Server Implementation

/// MCP server that handles approval prompt requests
actor ApprovalServer {
    private let logger: Logger
    private let server: Server
    
    init(logger: Logger) {
        self.logger = logger
        
        // Create MCP server with approval tool capability
        self.server = Server(
            name: "approval-server",
            version: "1.0.0",
            capabilities: .init(
                tools: .init(listChanged: false)
            )
        )
    }
    
    /// Set up MCP request handlers
    func setupHandlers() async {
        // Handle tool list requests
        await server.withMethodHandler(ListTools.self) { [weak self] _ in
            guard let self = self else {
                throw MCPError.internalError("Server deallocated")
            }
            
            await self.logger.info("Handling ListTools request")
            
            let tools = [
                Tool(
                    name: "approval_prompt",
                    description: "Handle permission approval requests for Claude Code tools",
                    inputSchema: .object([
                        "type": .string("object"),
                        "properties": .object([
                            "tool_name": .object([
                                "type": .string("string"),
                                "description": .string("The name of the tool requesting permission")
                            ]),
                            "input": .object([
                                "type": .string("object"),
                                "description": .string("The input parameters for the tool")
                            ]),
                            "tool_use_id": .object([
                                "type": .string("string"),
                                "description": .string("Unique identifier for this tool use request")
                            ])
                        ]),
                        "required": .array([.string("tool_name"), .string("input"), .string("tool_use_id")])
                    ])
                )
            ]
            
            return .init(tools: tools)
        }
        
        // Handle tool call requests
        await server.withMethodHandler(CallTool.self) { [weak self] params in
            guard let self = self else {
                throw MCPError.internalError("Server deallocated")
            }
            
            await self.logger.info("Handling CallTool request for: \(params.name)")
            
            // Only handle approval_prompt tool
            guard params.name == "approval_prompt" else {
                throw MCPError.invalidParams("Unknown tool: \(params.name)")
            }
            
            // Process the approval request
            return try await self.handleApprovalRequest(params.arguments)
        }
    }
    
    /// Handle approval prompt tool call
    private func handleApprovalRequest(_ arguments: [String: Value]?) async throws -> CallTool.Result {
        guard let arguments = arguments else {
            throw MCPError.invalidParams("Missing arguments for approval_prompt")
        }
        
        // Extract required parameters
        guard let toolName = arguments["tool_name"]?.stringValue else {
            throw MCPError.invalidParams("Missing tool_name parameter")
        }
        
        guard let toolUseId = arguments["tool_use_id"]?.stringValue else {
            throw MCPError.invalidParams("Missing tool_use_id parameter")
        }
        
        guard let inputObject = arguments["input"]?.objectValue else {
            throw MCPError.invalidParams("Missing input parameter")
        }
        
        logger.info("Processing approval request for tool: \(toolName), ID: \(toolUseId)")
        
        // Convert input to [String: Any] format
        let inputDict = convertValueToAny(inputObject)
        
        // Send approval request to main app via IPC
        logger.info("Sending approval request to main app via IPC for \(toolName) with ID: \(toolUseId)")
        
        do {
            let ipcResponse = try await sendIPCApprovalRequest(
                toolName: toolName,
                input: inputDict,
                toolUseId: toolUseId
            )
            
            // Convert IPC response to MCP format
            let mcpResponse: [String: Any] = [
                "behavior": ipcResponse.behavior,
                "updatedInput": convertSendableToAny(ipcResponse.updatedInput),
                "message": ipcResponse.message
            ]
            
            let responseData = try JSONSerialization.data(withJSONObject: mcpResponse, options: [])
            let responseString = String(data: responseData, encoding: .utf8) ?? "{}"
            
            logger.info("Approval request processed via IPC for \(toolUseId): \(ipcResponse.behavior)")
            
            return .init(
                content: [.text(responseString)],
                isError: false
            )
            
        } catch {
            logger.error("Failed to process approval request via IPC for \(toolUseId): \(error)")
            
            // Return denial on IPC failure
            let errorResponse: [String: Any] = [
                "behavior": "deny",
                "updatedInput": inputDict,
                "message": "IPC communication failed: \(error.localizedDescription)"
            ]
            
            let errorData = try JSONSerialization.data(withJSONObject: errorResponse, options: [])
            let errorString = String(data: errorData, encoding: .utf8) ?? "{}"
            
            return .init(
                content: [.text(errorString)],
                isError: true
            )
        }
    }
    
    /// Send approval request to main app via IPC and wait for response
    private func sendIPCApprovalRequest(toolName: String, input: [String: Any], toolUseId: String) async throws -> IPCResponse {
        logger.info("Preparing IPC request for tool: \(toolName), ID: \(toolUseId)")
        
        // Create IPC request
        let ipcRequest = IPCRequest(toolName: toolName, input: input, toolUseId: toolUseId)
        
        // Setup response listener first
        let responsePromise = setupResponseListener(for: toolUseId)
        
        // Send request via distributed notifications
        try sendIPCRequest(ipcRequest)
        
        // Wait for response with timeout
        return try await withTimeout(seconds: 240) {
            try await responsePromise.value
        }
    }
    
    /// Setup response listener for specific tool use ID
    private func setupResponseListener(for toolUseId: String) -> Task<IPCResponse, Swift.Error> {
        return Task<IPCResponse, Swift.Error> {
            return try await withCheckedThrowingContinuation { continuation in
                let notificationCenter = DistributedNotificationCenter.default()
                var observer: NSObjectProtocol?
                
                // Use a cleanup helper that captures the observer
                let cleanup = {
                    if let obs = observer {
                        notificationCenter.removeObserver(obs)
                    }
                }
                
                observer = notificationCenter.addObserver(
                    forName: NSNotification.Name("ClaudeCodeUIApprovalResponse"),
                    object: nil,
                    queue: .main
                ) { notification in
                    do {
                        guard let userInfo = notification.userInfo,
                              let responseData = userInfo["response"] as? Data else {
                            cleanup()
                            continuation.resume(throwing: IPCError.invalidResponse("Missing response data"))
                            return
                        }
                        
                        let decoder = JSONDecoder()
                        let response = try decoder.decode(IPCResponse.self, from: responseData)
                        
                        // Only handle response for this specific tool use ID
                        if response.toolUseId == toolUseId {
                            cleanup()
                            continuation.resume(returning: response)
                        }
                        
                    } catch {
                        cleanup()
                        continuation.resume(throwing: IPCError.decodingError(error.localizedDescription))
                    }
                }
                
                // Setup timeout cleanup
                Task {
                    try await Task.sleep(for: .seconds(245)) // Slightly longer than main timeout
                    cleanup()
                    continuation.resume(throwing: IPCError.timeout)
                }
            }
        }
    }
    
    /// Send IPC request to main app
    private func sendIPCRequest(_ request: IPCRequest) throws {
        let encoder = JSONEncoder()
        let requestData = try encoder.encode(request)
        
        let userInfo = ["request": requestData]
        
        let notificationCenter = DistributedNotificationCenter.default()
        notificationCenter.post(
            name: NSNotification.Name("ClaudeCodeUIApprovalRequest"),
            object: nil,
            userInfo: userInfo
        )
        
        logger.info("Sent IPC approval request for \(request.toolUseId)")
    }
    
    /// Add timeout wrapper for async operations
    private func withTimeout<T: Sendable>(seconds: TimeInterval, operation: @escaping @Sendable () async throws -> T) async throws -> T {
        return try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask {
                try await operation()
            }
            
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw IPCError.timeout
            }
            
            guard let result = try await group.next() else {
                throw IPCError.timeout
            }
            
            group.cancelAll()
            return result
        }
    }
    
    /// Convert Value dictionary to [String: Any]
    private func convertValueToAny(_ valueDict: [String: Value]) -> [String: Any] {
        var result: [String: Any] = [:]
        
        for (key, value) in valueDict {
            result[key] = convertValueToAny(value)
        }
        
        return result
    }
    
    /// Convert Value to Any
    private func convertValueToAny(_ value: Value) -> Any {
        switch value {
        case .string(let str):
            return str
        case .double(let num):
            return num
        case .int(let num):
            return num
        case .bool(let bool):
            return bool
        case .array(let arr):
            return arr.map { convertValueToAny($0) }
        case .object(let obj):
            return convertValueToAny(obj)
        case .data(mimeType: let mimeType, let data):
            return ["mimeType": mimeType, "data": data]
        case .null:
            return NSNull()
        }
    }
    
    /// Convert SendableValue dictionary back to [String: Any] for JSON serialization
    private func convertSendableToAny(_ sendableDict: [String: SendableValue]) -> [String: Any] {
        var result: [String: Any] = [:]
        for (key, value) in sendableDict {
            result[key] = convertSendableValueToAny(value)
        }
        return result
    }
    
    /// Convert SendableValue to Any
    private func convertSendableValueToAny(_ value: SendableValue) -> Any {
        switch value {
        case .string(let str):
            return str
        case .integer(let num):
            return num
        case .double(let num):
            return num
        case .boolean(let bool):
            return bool
        case .array(let arr):
            return arr.map { convertSendableValueToAny($0) }
        case .dictionary(let dict):
            return convertSendableToAny(dict)
        case .null:
            return NSNull()
        }
    }
    
    /// Run the MCP server
    func run() async throws {
        logger.info("Starting Approval MCP Server...")
        
        // Set up handlers first
        await setupHandlers()
        
        // Create stdio transport for Claude Code CLI communication
        let transport = StdioTransport(logger: logger)
        
        // Start the server with stdio transport
        try await server.start(transport: transport) { clientInfo, clientCapabilities in
            await self.logger.info("Client connected: \(clientInfo.name) v\(clientInfo.version)")
            
            // Log client capabilities
            await self.logger.info("Client capabilities received")
            
            // Accept all client connections
        }
        
        logger.info("Approval MCP Server started successfully")
        
        // Keep the server running
        try await Task.sleep(for: .seconds(86400 * 365)) // 1 year
    }
}

// MARK: - IPC Data Models

/// Sendable wrapper for various JSON value types
enum SendableValue: Codable, Sendable {
    case string(String)
    case integer(Int)
    case double(Double)
    case boolean(Bool)
    case array([SendableValue])
    case dictionary([String: SendableValue])
    case null
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let stringValue = try? container.decode(String.self) {
            self = .string(stringValue)
        } else if let intValue = try? container.decode(Int.self) {
            self = .integer(intValue)
        } else if let doubleValue = try? container.decode(Double.self) {
            self = .double(doubleValue)
        } else if let boolValue = try? container.decode(Bool.self) {
            self = .boolean(boolValue)
        } else if let arrayValue = try? container.decode([SendableValue].self) {
            self = .array(arrayValue)
        } else if let dictValue = try? container.decode([String: SendableValue].self) {
            self = .dictionary(dictValue)
        } else if container.decodeNil() {
            self = .null
        } else {
            throw DecodingError.typeMismatch(SendableValue.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unable to decode SendableValue"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
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

/// Convert [String: Any] to [String: SendableValue]
func convertDictToSendable(_ dict: [String: Any]) -> [String: SendableValue] {
    var result: [String: SendableValue] = [:]
    
    for (key, value) in dict {
        result[key] = convertValueToSendable(value)
    }
    
    return result
}

/// Convert Any to SendableValue
func convertValueToSendable(_ value: Any) -> SendableValue {
    switch value {
    case let stringVal as String:
        return .string(stringVal)
    case let intVal as Int:
        return .integer(intVal)
    case let doubleVal as Double:
        return .double(doubleVal)
    case let boolVal as Bool:
        return .boolean(boolVal)
    case let arrayVal as [Any]:
        return .array(arrayVal.map { convertValueToSendable($0) })
    case let dictVal as [String: Any]:
        return .dictionary(convertDictToSendable(dictVal))
    case is NSNull:
        return .null
    default:
        // Default to string representation for unknown types
        return .string(String(describing: value))
    }
}

/// Request sent from MCP server to main app
struct IPCRequest: Codable {
    let toolName: String
    let input: [String: Any]
    let toolUseId: String
    
    enum CodingKeys: String, CodingKey {
        case toolName = "tool_name"
        case input
        case toolUseId = "tool_use_id"
    }
    
    init(toolName: String, input: [String: Any], toolUseId: String) {
        self.toolName = toolName
        self.input = input
        self.toolUseId = toolUseId
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toolName = try container.decode(String.self, forKey: .toolName)
        toolUseId = try container.decode(String.self, forKey: .toolUseId)
        
        // Decode input as flexible JSON
        let inputContainer = try container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .input)
        var inputDict: [String: Any] = [:]
        
        for key in inputContainer.allKeys {
            if let stringValue = try? inputContainer.decode(String.self, forKey: key) {
                inputDict[key.stringValue] = stringValue
            } else if let intValue = try? inputContainer.decode(Int.self, forKey: key) {
                inputDict[key.stringValue] = intValue
            } else if let doubleValue = try? inputContainer.decode(Double.self, forKey: key) {
                inputDict[key.stringValue] = doubleValue
            } else if let boolValue = try? inputContainer.decode(Bool.self, forKey: key) {
                inputDict[key.stringValue] = boolValue
            }
        }
        
        input = inputDict
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toolName, forKey: .toolName)
        try container.encode(toolUseId, forKey: .toolUseId)
        
        // Encode input - simplified for basic types
        var inputContainer = container.nestedContainer(keyedBy: DynamicCodingKey.self, forKey: .input)
        for (key, value) in input {
            let codingKey = DynamicCodingKey(stringValue: key)!
            if let stringValue = value as? String {
                try inputContainer.encode(stringValue, forKey: codingKey)
            } else if let intValue = value as? Int {
                try inputContainer.encode(intValue, forKey: codingKey)
            } else if let doubleValue = value as? Double {
                try inputContainer.encode(doubleValue, forKey: codingKey)
            } else if let boolValue = value as? Bool {
                try inputContainer.encode(boolValue, forKey: codingKey)
            }
        }
    }
}

/// Response sent from main app to MCP server
struct IPCResponse: Codable, Sendable {
    let toolUseId: String
    let behavior: String
    let updatedInput: [String: SendableValue]
    let message: String
    
    enum CodingKeys: String, CodingKey {
        case toolUseId = "tool_use_id"
        case behavior
        case updatedInput = "updated_input"
        case message
    }
    
    init(toolUseId: String, behavior: String, updatedInput: [String: Any], message: String) {
        self.toolUseId = toolUseId
        self.behavior = behavior
        self.updatedInput = convertDictToSendable(updatedInput)
        self.message = message
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        toolUseId = try container.decode(String.self, forKey: .toolUseId)
        behavior = try container.decode(String.self, forKey: .behavior)
        message = try container.decode(String.self, forKey: .message)
        
        // Decode updatedInput as SendableValue dictionary
        updatedInput = try container.decode([String: SendableValue].self, forKey: .updatedInput)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(toolUseId, forKey: .toolUseId)
        try container.encode(behavior, forKey: .behavior)
        try container.encode(message, forKey: .message)
        
        // Encode updatedInput as SendableValue dictionary  
        try container.encode(updatedInput, forKey: .updatedInput)
    }
}

/// IPC error types
enum IPCError: Swift.Error {
    case timeout
    case invalidResponse(String)
    case decodingError(String)
    case encodingError(String)
}

/// Dynamic coding key for flexible JSON encoding/decoding
struct DynamicCodingKey: CodingKey {
    var stringValue: String
    var intValue: Int?
    
    init?(stringValue: String) {
        self.stringValue = stringValue
        self.intValue = nil
    }
    
    init?(intValue: Int) {
        self.stringValue = String(intValue)
        self.intValue = intValue
    }
}