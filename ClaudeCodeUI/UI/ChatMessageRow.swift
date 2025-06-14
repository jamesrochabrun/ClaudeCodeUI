//
//  ChatMessageRow.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import Foundation
import SwiftUI

struct ChatMessageRow: View {
  let message: ChatMessage
  @Environment(\.colorScheme) private var colorScheme
  @State private var isHovered = false
  @State private var showTimestamp = false
  @State private var settingsStorage = DependencyContainer.shared.settingsStorage
  
  var body: some View {
    HStack(alignment: .top, spacing: 12) {
      // Avatar for assistant messages
      if message.role == .assistant {
        avatarView
          .frame(width: 32, height: 32)
          .transition(.scale.combined(with: .opacity))
      }
      
      VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
        // Message header for special types
        if message.role == .assistant && message.messageType != .text {
          messageTypeHeader
        }
        
        // Main message bubble
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
      .frame(maxWidth: message.role == .user ? nil : .infinity, alignment: message.role == .user ? .trailing : .leading)
    }
    .padding(.horizontal)
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
  
  private var messageBubbleBackground: some View {
    Group {
      if message.role == .user {
        // No background for user messages
        Color.clear
      } else {
        // Assistant message bubble with glassmorphism effect
        ZStack {
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(.ultraThinMaterial)
          
          RoundedRectangle(cornerRadius: 18, style: .continuous)
            .strokeBorder(
              LinearGradient(
                colors: [
                  messageTint.opacity(0.3),
                  messageTint.opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1
            )
        }
        .shadow(color: messageTint.opacity(0.1), radius: 5, x: 0, y: 2)
      }
    }
  }
  
  @ViewBuilder
  private var messageTypeHeader: some View {
    HStack(spacing: 6) {
      Image(systemName: headerIcon)
        .font(.caption)
        .foregroundStyle(messageTint)
      
      Text(roleLabel)
        .font(.caption)
        .fontWeight(.medium)
        .foregroundStyle(messageTint)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
    .background(
      Capsule()
        .fill(messageTint.opacity(0.1))
        .overlay(
          Capsule()
            .strokeBorder(messageTint.opacity(0.2), lineWidth: 1)
        )
    )
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
    .padding(.vertical, 12)
    .padding(.horizontal, 16)
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
  private var avatarView: some View {
    ZStack {
      Circle()
        .fill(
          LinearGradient(
            colors: [messageTint.opacity(0.2), messageTint.opacity(0.1)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
          )
        )
      
      Image(systemName: avatarIcon)
        .font(.system(size: 16, weight: .medium))
        .foregroundStyle(messageTint)
    }
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
  
  private func copyMessage() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(message.content, forType: .string)
  }
  
  private var avatarIcon: String {
    switch message.messageType {
    case .text: return "bubble.left.fill"
    case .toolUse: return "hammer.fill"
    case .toolResult: return "checkmark.circle.fill"
    case .toolError: return "exclamationmark.triangle.fill"
    case .thinking: return "brain"
    case .webSearch: return "globe"
    }
  }
  
  private var headerIcon: String {
    switch message.messageType {
    case .text: return "text.bubble"
    case .toolUse: return "terminal"
    case .toolResult: return "checkmark.seal"
    case .toolError: return "xmark.octagon"
    case .thinking: return "brain"
    case .webSearch: return "safari"
    }
  }
  
  private var roleLabel: String {
    switch message.messageType {
    case .text: return message.role == .assistant ? "Claude" : "You"
    case .toolUse: return message.toolName ?? "Tool Use"
    case .toolResult: return "Result"
    case .toolError: return "Error"
    case .thinking: return "Thinking"
    case .webSearch: return "Searching"
    }
  }
  
  private var messageTint: Color {
    switch message.messageType {
    case .text:
      return message.role == .assistant ? Color(red: 147, green: 51, blue: 234) : Color(red: 0, green: 122, blue: 255)
    case .toolUse:
      return Color(red: 255, green: 149, blue: 0)
    case .toolResult:
      return Color(red: 52, green: 199, blue: 89)
    case .toolError:
      return Color(red: 255, green: 59, blue: 48)
    case .thinking:
      return Color(red: 90, green: 200, blue: 250)
    case .webSearch:
      return Color(red: 0, green: 199, blue: 190)
    }
  }
  
  private var messageFont: Font {
    switch message.messageType {
    case .text, .thinking, .webSearch:
      return .system(size: settingsStorage.fontSize)
    case .toolUse, .toolResult, .toolError:
      return .system(size: settingsStorage.fontSize - 1, design: .monospaced)
    }
  }
  
  private var contentTextColor: Color {
    colorScheme == .dark ? .white : .black.opacity(0.85)
  }
  
  private var shadowColor: Color {
    colorScheme == .dark
    ? Color.white.opacity(0.03)
    : Color.black.opacity(0.08)
  }
  
  private var timeFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
  }
  
  @State private var animationValues: [Bool] = [false, false, false]
}

#Preview {
  ScrollView {
    VStack(spacing: 8) {
      ChatMessageRow(message: ChatMessage(
        role: .user,
        content: "Can you help me analyze this codebase?"
      ))
      
      ChatMessageRow(message: ChatMessage(
        role: .assistant,
        content: "I'd be happy to help you analyze your codebase! Let me start by exploring the project structure.",
        messageType: .text
      ))
      
      ChatMessageRow(message: ChatMessage(
        role: .assistant,
        content: "find . -type f -name '*.swift' | head -20",
        messageType: .toolUse,
        toolName: "Bash"
      ))
      
      ChatMessageRow(message: ChatMessage(
        role: .assistant,
        content: "./main.swift\n./Sources/App.swift\n./Sources/Models/User.swift\n./Sources/Views/ContentView.swift",
        messageType: .toolResult
      ))
      
      ChatMessageRow(message: ChatMessage(
        role: .assistant,
        content: "Error: Command not found",
        messageType: .toolError
      ))
      
      ChatMessageRow(message: ChatMessage(
        role: .assistant,
        content: "Analyzing the project structure...",
        messageType: .thinking
      ))
    }
    .padding()
  }
  .frame(width: 600, height: 800)
  .background(Color(NSColor.windowBackgroundColor))
}
