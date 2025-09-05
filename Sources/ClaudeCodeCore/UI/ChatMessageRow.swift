//
//  ChatMessageRow.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

// LEGACY: This view is now legacy. Use ChatMessageView instead.

import Foundation
import SwiftUI

struct ChatMessageRow: View {
  let message: ChatMessage
  let settingsStorage: SettingsStorage
  let fontSize: Double
  
  // Constants
  private let bubbleCornerRadius: CGFloat = 6
  private let fontDesign: Font.Design = .monospaced
  
  init(
    message: ChatMessage,
    settingsStorage: SettingsStorage,
    fontSize: Double = 13.0)
  {
    self.message = message
    self.settingsStorage = settingsStorage
    self.fontSize = fontSize
    
    // Set default expanded state based on tool type or message type
    var defaultExpanded = false
    
    // Check if it's a tool that should be expanded by default
    if let toolName = message.toolName,
       let tool = ToolRegistry.shared.tool(for: toolName) {
      defaultExpanded = tool.defaultExpandedState
    }
    
    // Thinking messages should also be expanded by default
    if message.messageType == .thinking {
      defaultExpanded = true
    }
    
    self._isExpanded = State(initialValue: defaultExpanded)
  }
  
  @Environment(\.colorScheme) private var colorScheme
  @State private var isHovered = false
  @State private var showTimestamp = false
  @State private var isExpanded: Bool
  
  // Determine if this message type should be collapsible
  private var isCollapsible: Bool {
    switch message.messageType {
    case .toolUse, .toolResult, .toolError, .thinking, .webSearch:
      return true
    case .text:
      return false
    }
  }
  
  // Check if this is a user or assistant text message
  private var isUserOrAssistantMessage: Bool {
    return (message.role == .user || message.role == .assistant) && message.messageType == .text
  }
  
  // Message prefix based on role
  private var messagePrefix: String {
    switch message.role {
    case .user:
      return ">"
    default:
      return ""
    }
  }
  
  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      if isCollapsible {
        collapsibleMessageView
      } else {
        standardMessageView
      }
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
    .onHover { hovering in
      withAnimation(.easeInOut(duration: 0.2)) {
        isHovered = hovering
      }
    }
    .contextMenu {
      contextMenuItems
    }
  }
  
  // MARK: - Collapsible Message View
  @ViewBuilder
  private var collapsibleMessageView: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header that's always visible
      HStack(spacing: 12) {
        // Checkmark indicator
        Image(systemName: isExpanded ? "checkmark.circle.fill" : "checkmark.circle")
          .font(.system(size: 14))
          .foregroundStyle(statusColor)
          .frame(width: 20, height: 20)
        
        // Message type label
        Text(collapsibleHeaderText)
          .font(.system(size: fontSize - 1, design: fontDesign))
          .foregroundStyle(.primary)
        
        Spacer()
        
        // Expand/collapse chevron
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
          .rotationEffect(.degrees(isExpanded ? 90 : 0))
      }
      .padding(.horizontal, 8)
      .padding(.vertical, 4)
      .background(
        RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous)
          .fill(.ultraThinMaterial)
          .overlay(
            RoundedRectangle(cornerRadius: bubbleCornerRadius, style: .continuous)
              .strokeBorder(
                LinearGradient(
                  colors: [
                    Color(red: 147/255, green: 51/255, blue: 234/255).opacity(0.3),
                    Color(red: 147/255, green: 51/255, blue: 234/255).opacity(0.1)
                  ],
                  startPoint: .topLeading,
                  endPoint: .bottomTrailing
                ),
                lineWidth: 1
              )
          )
      )
      .contentShape(Rectangle())
      .onTapGesture {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
          isExpanded.toggle()
        }
      }
      
      // Expandable content
      if isExpanded {
        VStack(alignment: .leading, spacing: 0) {
          // Connection line
          HStack(spacing: 0) {
            Color.clear
              .frame(width: 20)
            
            Rectangle()
              .fill(borderColor)
              .frame(width: 2)
              .padding(.vertical, -1)
          }
          .frame(height: 8)
          
          // Content area
          HStack(alignment: .top, spacing: 0) {
            Color.clear
              .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 0) {
              Rectangle()
                .fill(borderColor)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
              
              // Message content
              ScrollView {
                Text(message.content)
                  .font(.system(size: fontSize - 1, design: fontDesign))
                  .foregroundColor(contentTextColor)
                  .padding(16)
                  .frame(maxWidth: .infinity, alignment: .leading)
                  .textSelection(.enabled)
              }
              .frame(maxHeight: 400)
              .background(contentBackgroundColor)
            }
          }
        }
        .transition(.asymmetric(
          insertion: .push(from: .top).combined(with: .opacity),
          removal: .push(from: .bottom).combined(with: .opacity)
        ))
      }
    }
  }
  
  // MARK: - Standard Message View
  @ViewBuilder
  private var standardMessageView: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Code selections for user messages (leading position)
      if message.role == .user, let codeSelections = message.codeSelections, !codeSelections.isEmpty {
        codeSelectionsView(selections: codeSelections)
          .padding(.top, 6)
      }
      
      HStack(alignment: .firstTextBaseline, spacing: 8) {
        // Prefix for user and assistant messages
        if isUserOrAssistantMessage {
          Text(messagePrefix)
            .font(messageFont)
            .foregroundStyle(.secondary)
        }
        
        // Main message content
        messageContentView
          .background(messageBubbleBackground)
          .overlay(alignment: message.role == .user ? .bottomTrailing : .bottomLeading) {
            if isHovered || showTimestamp {
              timestampView
                .transition(.asymmetric(
                  insertion: .scale(scale: 0.8).combined(with: .opacity),
                  removal: .scale(scale: 0.8).combined(with: .opacity)
                ))
            }
          }
      }
    }
    .frame(maxWidth: message.role == .user ? nil : .infinity, alignment: message.role == .user ? .trailing : .leading)
  }
  
  // MARK: - Helper Views
  private var messageBubbleBackground: some View {
    // No background for any text messages
    Color.clear
  }
  
  @ViewBuilder
  private var messageContentView: some View {
    Group {
      if message.content.isEmpty && !message.isComplete {
        loadingView
      } else {
        Text(message.content)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
          .foregroundColor(contentTextColor)
          .font(messageFont)
      }
    }
    .padding(.vertical, isUserOrAssistantMessage ? 4 : 12)
    .padding(.trailing, 12)
    .padding(.leading, message.role == .assistant ? 4 : (isUserOrAssistantMessage ? 0 : 12))
    .frame(maxWidth: .infinity, alignment: .leading)
  }
  
  @ViewBuilder
  private var loadingView: some View {
    HStack(spacing: 8) {
      ForEach(0..<3) { index in
        Circle()
          .fill(
            LinearGradient(
              colors: [messageTint, messageTint.opacity(0.6)],
              startPoint: .top,
              endPoint: .bottom
            )
          )
          .frame(width: 8, height: 8)
          .scaleEffect(animationValues[index] ? 1.2 : 0.8)
          .animation(
            Animation.easeInOut(duration: 0.6)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.15),
            value: animationValues[index]
          )
          .onAppear {
            animationValues[index].toggle()
          }
      }
    }
    .padding(.vertical, 4)
  }
  
  @ViewBuilder
  private var timestampView: some View {
    Text(timeFormatter.string(from: message.timestamp))
      .font(.caption2)
      .foregroundColor(.secondary)
      .padding(.horizontal, 8)
      .padding(.vertical, 2)
      .background(
        Capsule()
          .fill(.ultraThinMaterial)
      )
      .offset(y: 25)
  }
  
  @ViewBuilder
  private var contextMenuItems: some View {
    Button(action: copyMessage) {
      Label("Copy", systemImage: "doc.on.doc")
    }
    
    if message.role == .assistant {
      Button(action: { showTimestamp.toggle() }) {
        Label(showTimestamp ? "Hide Timestamp" : "Show Timestamp",
              systemImage: "clock")
      }
    }
  }
  
  // MARK: - Helper Functions
  private func copyMessage() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(message.content, forType: .string)
  }
  
  // MARK: - Computed Properties
  private var collapsibleHeaderText: String {
    switch message.messageType {
    case .toolUse:
      let toolName = message.toolName ?? "Tool Use"
      return message.toolInputData?.headerText(for: toolName) ?? toolName
    case .toolResult:
      return "Processing result"
    case .toolError:
      return "Error occurred"
    case .thinking:
      return "Thinking..."
    case .webSearch:
      return "Searching the web"
    default:
      return "Processing"
    }
  }
  
  private var statusColor: Color {
    switch message.messageType {
    case .toolUse, .thinking, .webSearch:
      return .brandPrimary
    case .toolResult:
      return .brandTertiary
    case .toolError:
      return .red
    default:
      return .secondary
    }
  }
  
  private var collapsibleBackgroundColor: Color {
    colorScheme == .dark
    ? Color(white: 0.15)
    : Color(white: 0.95)
  }
  
  private var contentBackgroundColor: Color {
    colorScheme == .dark
    ? Color(white: 0.1)
    : Color.white
  }
  
  private var borderColor: Color {
    colorScheme == .dark
    ? Color(white: 0.25)
    : Color(white: 0.85)
  }
  
  private var messageTint: Color {
    switch message.messageType {
    case .text:
      return message.role == .assistant ? Color(red: 147/255, green: 51/255, blue: 234/255) : .primary
    case .toolUse:
      return Color(red: 255/255, green: 149/255, blue: 0/255)
    case .toolResult:
      return Color(red: 52/255, green: 199/255, blue: 89/255)
    case .toolError:
      return Color(red: 255/255, green: 59/255, blue: 48/255)
    case .thinking:
      return Color(red: 90/255, green: 200/255, blue: 250/255)
    case .webSearch:
      return Color(red: 0/255, green: 199/255, blue: 190/255)
    }
  }
  
  private var messageFont: Font {
    guard (message.role == .user || message.role == .assistant) else {
      return .system(size: fontSize, weight: colorScheme == .dark ? .ultraLight : .light, design: fontDesign)
    }
    return Font.system(.body)
  }
  
  private var contentTextColor: Color {
    colorScheme == .dark ? .white : .black.opacity(0.85)
  }
  
  private var timeFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
  }
  
  @State private var animationValues: [Bool] = [false, false, false]
  
  // MARK: - Code Selections View
  @ViewBuilder
  private func codeSelectionsView(selections: [TextSelection]) -> some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(selections) { selection in
        ActiveFileView(model: .selection(selection))
          .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
          ))
      }
    }
  }
}
