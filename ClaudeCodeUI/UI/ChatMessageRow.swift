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
  
  private var assistantUseHeader: some View {
    HStack(spacing: 4) {
      avatarView
      Text(roleLabel)
        .fontWeight(.medium)
        .foregroundColor(roleLabelColor)
      
      Text(timeFormatter.string(from: message.timestamp))
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .font(.caption)
    .padding(.horizontal, 4)
    .background(
      RoundedRectangle(cornerRadius: 8, style: .continuous)
        .fill(.ultraThinMaterial)
    )
  }
  
  var body: some View {
    ZStack(alignment: .topLeading) {
      HStack(alignment: .top, spacing: 10) {
        messageContentView
          .padding(.top, 10)
          .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
              .fill(.clear) // Add back the background fill
              .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                  .stroke(borderColor, lineWidth: 1)
              )
              .shadow(color: shadowColor, radius: 1, x: 0, y: 0.5)
          )
          .contextMenu {
            Button(action: {
              NSPasteboard.general.clearContents()
              NSPasteboard.general.setString(message.content, forType: .string)
            }) {
              Label("Copy", systemImage: "doc.on.doc")
            }
          }
      }
      if message.role != .user {
        assistantUseHeader
          .offset(x: 10, y: -8) // Use offset instead of padding
      }
    }
    .padding(.top, 10) // Add space for the offset header
    .animation(.easeInOut(duration: 0.2), value: message.isComplete)
  }
  
  @ViewBuilder
  private var messageContentView: some View {
    VStack {
      if message.content.isEmpty && !message.isComplete {
        loadingView
      } else {
        Text(message.content)
          .textSelection(.enabled)
          .fixedSize(horizontal: false, vertical: true)
          .foregroundColor(contentTextColor)
      }
    }
    .padding(.vertical, message.role == .user ? 8 : 4)
    .padding(.horizontal, 12)
    .padding(.top, message.role == .user ? 8 : 4)
    .padding(.bottom, 8)
    .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)
  }
  
  @ViewBuilder
  private var loadingView: some View {
    HStack(spacing: 4) {
      ForEach(0..<3) { index in
        Circle()
          .fill(messageTint.opacity(0.6))
          .frame(width: 6, height: 6)
          .scaleEffect(animationValues[index] ? 1.0 : 0.5)
          .animation(
            Animation.easeInOut(duration: 0.5)
              .repeatForever(autoreverses: true)
              .delay(Double(index) * 0.2),
            value: animationValues[index]
          )
          .onAppear {
            animationValues[index].toggle()
          }
      }
    }
    .frame(height: 18)
    .frame(width: 36)
  }
  
  @ViewBuilder
  private var avatarView: some View {
    Group {
      if message.role == .user {
        EmptyView()
      } else {
        Image(systemName: avatarIcon)
          .foregroundStyle(messageTint.opacity(0.8))
          .font(.caption)
      }
    }
  }
  
  private var avatarIcon: String {
    switch message.messageType {
    case .text: return "circle"
    case .toolUse: return "hammer.circle.fill"
    case .toolResult: return "checkmark.circle.fill"
    case .toolError: return "exclamationmark.circle.fill"
    case .thinking: return "brain.fill"
    case .webSearch: return "globe.circle.fill"
    }
  }
  
  private var roleLabel: String {
    switch message.messageType {
    case .text: return message.role == .assistant ? "Claude Code" : "You"
    case .toolUse: return message.toolName ?? "Tool"
    case .toolResult: return "Result"
    case .toolError: return "Error"
    case .thinking: return "Thinking"
    case .webSearch: return "Web Search"
    }
  }
  
  private var roleLabelColor: Color {
    messageTint.opacity(0.9)
  }
  
  private var messageTint: Color {
    switch message.messageType {
    case .text: return message.role == .assistant ? .purple : .blue
    case .toolUse: return .orange
    case .toolResult: return .green
    case .toolError: return .red
    case .thinking: return .blue
    case .webSearch: return .teal
    }
  }
  
  private var backgroundColor: Color {
    colorScheme == .dark
    ? Color.gray.opacity(0.15)
    : Color.gray.opacity(0.08)
  }
  
  private var borderColor: Color {
    if message.role != .user {
      Color.secondary.opacity(0.5)
      //Color(red: 222, green: 209, blue: 177)
    } else {
      .clear
    }
   // Color(red: 195, green: 148, blue: 116)
    //    colorScheme == .dark
    //    ? Color.gray.opacity(0.3)
    //    : Color.gray.opacity(0.2)
  }
  
  private var contentTextColor: Color {
    colorScheme == .dark ? .white : .primary
  }
  
  private var shadowColor: Color {
    colorScheme == .dark ? .clear : Color.black.opacity(0.03)
  }
  
  private var timeFormatter: DateFormatter {
    let formatter = DateFormatter()
    formatter.timeStyle = .short
    return formatter
  }
  
  @State private var animationValues: [Bool] = [false, false, false]
}

#Preview {
  List {
    ChatMessageRow(message: .init(role: .toolUse, content: "$ ls-la"))
    ChatMessageRow(message: .init(role: .user, content: "Hello"))
    ChatMessageRow(message: .init(role: .toolError, content: """
      {"type":"result","subtype":"success","cost_usd":0.0111402,"is_error":false,"duration_ms":1314}
      """))
    ChatMessageRow(message: .init(role: .toolResult, content: "$ ls-la"))
  }
}
