//
//  TaskGroupView.swift
//  ClaudeCodeUI
//
//  Created on 1/13/2025.
//

import SwiftUI
import CCTerminalServiceInterface

/// View that displays a Task tool with all its nested tool executions in a collapsible format
struct TaskGroupView: View {
  let taskMessage: ChatMessage
  let groupedMessages: [ChatMessage]
  let settingsStorage: SettingsStorage
  let terminalService: TerminalService
  let fontSize: Double
  let showArtifact: ((Artifact) -> Void)?
  
  @Environment(\.colorScheme) private var colorScheme
  
  /// Gets the latest tool status (either executing or last completed)
  var latestToolStatus: (tool: ChatMessage, isExecuting: Bool)? {
    // First, check if there's a currently executing tool
    for i in stride(from: groupedMessages.count - 1, through: 0, by: -1) {
      let message = groupedMessages[i]
      if message.messageType == .toolUse {
        // Check if this tool has a result
        var hasResult = false
        if i + 1 < groupedMessages.count {
          let nextMessage = groupedMessages[i + 1]
          if nextMessage.messageType == .toolResult || nextMessage.messageType == .toolError {
            hasResult = true
          }
        }
        
        if !hasResult {
          // This tool doesn't have a result yet, so it's currently executing
          return (tool: message, isExecuting: true)
        }
      }
    }
    
    // If no executing tool, find the last completed tool
    for i in stride(from: groupedMessages.count - 1, through: 0, by: -1) {
      let message = groupedMessages[i]
      if message.messageType == .toolUse {
        // This is the most recent tool (must be completed since we checked executing above)
        return (tool: message, isExecuting: false)
      }
    }
    
    return nil
  }
  
  
  /// Pairs tool uses with their corresponding results
  var pairedToolMessages: [(toolUse: ChatMessage, toolResult: ChatMessage?)] {
    var pairs: [(toolUse: ChatMessage, toolResult: ChatMessage?)] = []
    var i = 0
    
    while i < groupedMessages.count {
      let message = groupedMessages[i]
      
      if message.messageType == .toolUse {
        // Look for the next message to see if it's a result
        var result: ChatMessage? = nil
        if i + 1 < groupedMessages.count {
          let nextMessage = groupedMessages[i + 1]
          if nextMessage.messageType == .toolResult || nextMessage.messageType == .toolError {
            result = nextMessage
            i += 1 // Skip the result in the next iteration
          }
        }
        pairs.append((toolUse: message, toolResult: result))
      } else if message.messageType == .toolResult || message.messageType == .toolError {
        // Orphaned result without a tool use - create a placeholder tool use
        let placeholderToolUse = ChatMessage(
          role: .toolUse,
          content: "TOOL USE: Processing",
          messageType: .toolUse,
          toolName: "Processing"
        )
        pairs.append((toolUse: placeholderToolUse, toolResult: message))
      }
      
      i += 1
    }
    
    return pairs
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      // Task header
      HStack(spacing: 8) {
        // Task icon
        Image(systemName: "play.circle")
          .font(.system(size: 14, weight: .medium))
          .foregroundColor(.bookCloth)
        
        // Task description with "Task: " prefix
        if let toolInputData = taskMessage.toolInputData,
           let description = toolInputData.parameters["description"] {
          Text("Task: \(description)")
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(.primary)
        } else {
          Text("Task: Runner")
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(.primary)
        }
        
        Spacer()
        
        // Summary stats
        HStack(spacing: 8) {
          // Show latest tool status
          if let status = latestToolStatus {
            HStack(spacing: 4) {
              if status.isExecuting {
                // Animated indicator for running tool
                Image(systemName: "circle.fill")
                  .font(.system(size: 6))
                  .foregroundColor(.bookCloth)
                  .animation(.easeInOut(duration: 1).repeatForever(autoreverses: true), value: status.tool.id)
                
                Text("Running: \(status.tool.toolName ?? "Processing")")
                  .font(.system(size: fontSize - 1))
                  .foregroundColor(.bookCloth)
                  .lineLimit(1)
              } else {
                // Static indicator for completed tool
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 10))
                  .foregroundColor(.kraft)
                
                Text("Completed: \(status.tool.toolName ?? "Processing")")
                  .font(.system(size: fontSize - 1))
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
            }
          }
          
          // Show total tools used
          if pairedToolMessages.count > 0 {
            Text("• \(pairedToolMessages.count) tools")
              .font(.system(size: fontSize - 1))
              .foregroundColor(.secondary)
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(headerBackgroundColor)
      .clipShape(RoundedRectangle(cornerRadius: 6))
      
      // Tool history content - always visible
      if !groupedMessages.isEmpty {
        VStack(alignment: .leading, spacing: 4) {
          // Section header showing current status
          HStack {
            Text("Tool History")
              .font(.system(size: fontSize - 2, weight: .medium))
              .foregroundColor(.secondary)
            
            if let status = latestToolStatus, status.isExecuting {
              Text("- Currently: \(status.tool.toolName ?? "Processing")")
                .font(.system(size: fontSize - 2))
                .foregroundColor(.bookCloth)
            }
          }
          .padding(.leading, 32)
          .padding(.top, 4)
          
          // Connection line and nested tools
          HStack(alignment: .top, spacing: 0) {
            // Vertical line
            Rectangle()
              .fill(borderColor)
              .frame(width: 2)
              .padding(.leading, 20)
            
            // Nested tools list - pair tool uses with their results
            VStack(alignment: .leading, spacing: 8) {
              ForEach(Array(pairedToolMessages.enumerated()), id: \.offset) { index, pair in
                CompactToolPairView(
                  toolUse: pair.toolUse,
                  toolResult: pair.toolResult,
                  fontSize: fontSize - 1,
                  terminalService: terminalService
                )
              }
            }
            .padding(.leading, 12)
          }
        }
      }
    }
  }
  
  private var headerBackgroundColor: Color {
    colorScheme == .dark
      ? Color.expandedContentBackgroundDark.opacity(0.6)
      : Color.expandedContentBackgroundLight.opacity(0.6)
  }
  
  private var borderColor: Color {
    colorScheme == .dark
      ? Color(white: 0.25)
      : Color(white: 0.85)
  }
}

/// Compact view for paired tool request/response within a task group
struct CompactToolPairView: View {
  let toolUse: ChatMessage
  let toolResult: ChatMessage?
  let fontSize: Double
  let terminalService: TerminalService
  
  @State private var showDetail = false
  @Environment(\.colorScheme) private var colorScheme
  private let toolRegistry = ToolRegistry.shared
  
  var body: some View {
    VStack(alignment: .leading, spacing: 4) {
      // Tool request/response header
      Button(action: { showDetail.toggle() }) {
        HStack(spacing: 8) {
          // Tool icon
          if let toolName = toolUse.toolName,
             let tool = toolRegistry.tool(for: toolName) {
            Image(systemName: tool.icon)
              .font(.system(size: 14))
              .foregroundColor(.bookCloth)
          }
          
          // Tool name and parameters
          VStack(alignment: .leading, spacing: 2) {
            // Request line
            HStack(spacing: 4) {
              Text(toolUse.toolName ?? "Tool")
                .font(.system(size: fontSize, weight: .medium))
                .foregroundColor(.primary)
              
              if let toolInputData = toolUse.toolInputData,
                 let firstParam = toolInputData.keyParameters.first {
                Text("- \(truncateValue(firstParam.value))")
                  .font(.system(size: fontSize))
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
            }
            
            // Response preview
            if let result = toolResult {
              HStack(spacing: 4) {
                Image(systemName: result.isError ? "xmark.circle.fill" : "arrow.turn.down.right")
                  .font(.system(size: 10))
                  .foregroundColor(result.isError ? .warmCoral : .kraft)
                
                Text(truncateResponse(result.content))
                  .font(.system(size: fontSize - 1))
                  .foregroundColor(.secondary)
                  .lineLimit(1)
              }
            } else if toolUse.toolName == "Processing" {
              // This is an orphaned result shown as a tool use
              HStack(spacing: 4) {
                Image(systemName: "checkmark.circle.fill")
                  .font(.system(size: 10))
                  .foregroundColor(.kraft)
                
                Text("Result processed")
                  .font(.system(size: fontSize - 1))
                  .foregroundColor(.secondary)
              }
            }
          }
          
          Spacer()
          
          // Expand indicator
          Image(systemName: showDetail ? "chevron.up.circle" : "chevron.down.circle")
            .font(.system(size: 12))
            .foregroundColor(.manilla)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(toolBackgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 6))
      }
      .buttonStyle(.plain)
      
      // Detailed content when expanded
      if showDetail {
        VStack(alignment: .leading, spacing: 8) {
          // Tool request details (skip for placeholder Processing tools)
          if toolUse.toolName != "Processing" {
            VStack(alignment: .leading, spacing: 4) {
              Text("Request:")
                .font(.system(size: fontSize - 1, weight: .semibold))
                .foregroundColor(.primary)
              
              Text(toolUse.content)
                .font(.system(size: fontSize - 1, design: .monospaced))
                .foregroundColor(.primary)
                .padding(8)
                .background(Color.secondary.opacity(0.05))
                .clipShape(RoundedRectangle(cornerRadius: 4))
            }
          }
          
          // Tool response details
          if let result = toolResult {
            VStack(alignment: .leading, spacing: 4) {
              HStack {
                Text("Response:")
                  .font(.system(size: fontSize - 1, weight: .semibold))
                  .foregroundColor(.primary)
                
                if result.isError {
                  Label("Error", systemImage: "exclamationmark.triangle.fill")
                    .font(.system(size: fontSize - 2))
                    .foregroundColor(.warmCoral)
                }
              }
              
              ScrollView {
                Text(result.content)
                  .font(.system(size: fontSize - 1, design: .monospaced))
                  .foregroundColor(.primary)
                  .padding(8)
                  .frame(maxWidth: .infinity, alignment: .leading)
              }
              .frame(maxHeight: 200)
              .background(result.isError ? Color.warmCoral.opacity(0.05) : Color.secondary.opacity(0.05))
              .clipShape(RoundedRectangle(cornerRadius: 4))
            }
          }
        }
        .padding(.leading, 20)
        .padding(.top, 4)
      }
    }
  }
  
  private var toolBackgroundColor: Color {
    colorScheme == .dark
      ? Color.secondary.opacity(0.08)
      : Color.secondary.opacity(0.04)
  }
  
  private func truncateValue(_ value: String) -> String {
    if value.count > 40 {
      return String(value.prefix(37)) + "..."
    }
    return value
  }
  
  private func truncateResponse(_ response: String) -> String {
    let cleanResponse = response
      .trimmingCharacters(in: .whitespacesAndNewlines)
      .replacingOccurrences(of: "\n", with: " ")
    
    if cleanResponse.count > 50 {
      return String(cleanResponse.prefix(47)) + "..."
    }
    return cleanResponse
  }
}