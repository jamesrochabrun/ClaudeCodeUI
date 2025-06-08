//
//  LoadingIndicator.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/8/2025.
//

import SwiftUI

struct LoadingIndicator: View {
  @State private var animationPhase = 0.0
  
  var body: some View {
    HStack(spacing: 8) {
      ForEach(0..<3) { index in
        Circle()
          .fill(Color.blue.opacity(0.7))
          .frame(width: 8, height: 8)
          .scaleEffect(animationPhase == Double(index) ? 1.5 : 1.0)
          .animation(
            .easeInOut(duration: 0.6)
            .repeatForever(autoreverses: true)
            .delay(Double(index) * 0.2),
            value: animationPhase
          )
      }
    }
    .padding(.horizontal, 20)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 20)
        .fill(Color(NSColor.controlBackgroundColor))
        .overlay(
          RoundedRectangle(cornerRadius: 20)
            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
    )
    .onAppear {
      animationPhase = 2.0
    }
  }
}

struct ThinkingIndicator: View {
  let message: String
  @State private var dots = ""
  
  let timer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
  
  var body: some View {
    HStack(spacing: 10) {
      Image(systemName: "brain")
        .font(.body)
        .foregroundColor(.blue)
        .symbolEffect(.pulse)
      
      Text("Claude is thinking\(dots)")
        .font(.callout)
        .fontWeight(.medium)
      
      if !message.isEmpty {
        Text("•")
          .foregroundColor(.secondary)
        Text(message)
          .font(.callout)
          .foregroundColor(.secondary)
          .lineLimit(1)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(
      RoundedRectangle(cornerRadius: 20)
        .fill(Color(NSColor.controlBackgroundColor))
        .overlay(
          RoundedRectangle(cornerRadius: 20)
            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    )
    .onReceive(timer) { _ in
      withAnimation {
        dots = dots.count < 3 ? dots + "." : ""
      }
    }
  }
}

#Preview("Loading Indicator") {
  VStack(spacing: 20) {
    LoadingIndicator()
    
    ThinkingIndicator(message: "Analyzing your code...")
    
    ThinkingIndicator(message: "")
  }
  .padding()
  .frame(width: 400)
}
