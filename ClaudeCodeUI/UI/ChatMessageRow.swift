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
  let settingsStorage: SettingsStorage
  let fontSize: Double
  
  init(
    message: ChatMessage,
    settingsStorage: SettingsStorage,
    fontSize: Double = 13.0)
  {
    self.message = message
    self.settingsStorage = settingsStorage
    self.fontSize = fontSize
  }
  
  @Environment(\.colorScheme) private var colorScheme
  @State private var isHovered = false
  @State private var showTimestamp = false
  @State private var isExpanded = false
  @State private var contentHeight: CGFloat = 0
  
  // Determine if this message type should be collapsible
  private var isCollapsible: Bool {
    switch message.messageType {
    case .toolUse, .toolResult, .toolError, .thinking, .webSearch:
      return true
    case .text:
      return false
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
          .font(.system(size: fontSize - 1))
          .foregroundStyle(.primary)
        
        Spacer()
        
        // Expand/collapse chevron
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .medium))
          .foregroundStyle(.secondary)
          .rotationEffect(.degrees(isExpanded ? 90 : 0))
      }
      .padding(.horizontal, 20)
      .padding(.vertical, 10)
      .background(
        RoundedRectangle(cornerRadius: 12, style: .continuous)
          .fill(collapsibleBackgroundColor)
          .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .strokeBorder(borderColor, lineWidth: 1)
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
              .frame(width: 30)
            
            Rectangle()
              .fill(borderColor)
              .frame(width: 1)
              .padding(.vertical, -1)
          }
          .frame(height: 8)
          
          // Content area
          HStack(alignment: .top, spacing: 0) {
            Color.clear
              .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 0) {
              Rectangle()
                .fill(borderColor)
                .frame(height: 1)
                .frame(maxWidth: .infinity)
              
              // Message content
              ScrollView {
                Text(message.content)
                  .font(.system(size: fontSize - 1, design: .monospaced))
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
    HStack(alignment: .top, spacing: 12) {
      // Avatar for assistant messages
      if message.role == .assistant {
        avatarView
          .frame(width: 32, height: 32)
          .transition(.scale.combined(with: .opacity))
      }
      
      VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
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
  }
  
  // MARK: - Helper Views
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
  
  // MARK: - Helper Functions
  private func copyMessage() {
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(message.content, forType: .string)
  }
  
  // MARK: - Computed Properties
  private var collapsibleHeaderText: String {
    switch message.messageType {
    case .toolUse:
      return message.toolName ?? "Tool Use"
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
      return .orange
    case .toolResult:
      return .green
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
  
  private var messageTint: Color {
    switch message.messageType {
    case .text:
      return message.role == .assistant ? Color(red: 147/255, green: 51/255, blue: 234/255) : Color(red: 0/255, green: 122/255, blue: 255/255)
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
    switch message.messageType {
    case .text, .thinking, .webSearch:
      return .system(size: fontSize)
    case .toolUse, .toolResult, .toolError:
      return .system(size: fontSize - 1, design: .monospaced)
    }
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
}
