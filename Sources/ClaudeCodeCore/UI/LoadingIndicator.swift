//
//  LoadingIndicator.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 6/29/2025.
//

import SwiftUI

struct LoadingIndicator: View {
  let startTime: Date
  let inputTokens: Int
  let outputTokens: Int
  let costUSD: Double
  let showPrice: Bool
  let showTokenCount: Bool
  
  @State private var elapsedTime: TimeInterval = 0
  @State private var dots = ""
  
  private let timer = Timer.publish(every: 0.1, on: .main, in: .common).autoconnect()
  private let dotsTimer = Timer.publish(every: 0.5, on: .main, in: .common).autoconnect()
  
  init(startTime: Date, inputTokens: Int = 0, outputTokens: Int = 0, costUSD: Double = 0.0, showPrice: Bool? = nil, showTokenCount: Bool = true) {
    self.startTime = startTime
    self.inputTokens = inputTokens
    self.outputTokens = outputTokens
    self.costUSD = costUSD
    self.showTokenCount = showTokenCount
    
    // Show price only in debug builds by default
    #if DEBUG
    self.showPrice = showPrice ?? true
    #else
    self.showPrice = showPrice ?? false
    #endif
  }
  
  private var totalTokens: Int {
    inputTokens + outputTokens
  }
  
  private var formattedTime: String {
    String(format: "%.0fs", elapsedTime)
  }
  
  private var hasTokenData: Bool {
    inputTokens > 0 || outputTokens > 0
  }
  
  private var statusText: String {
    var text = "Streaming\(dots) (\(formattedTime)"
    
    if showTokenCount && hasTokenData {
      text += " · \(totalTokens) tokens"
    }
    
    if showPrice && costUSD > 0 {
      text += " · $\(String(format: "%.4f", costUSD))"
    }
    
    text += " · esc to interrupt)"
    
    return text
  }
  
  var body: some View {
    Text(statusText)
      .font(.system(size: 12))
      .foregroundColor(.secondary)
      .onReceive(timer) { _ in
        elapsedTime = Date().timeIntervalSince(startTime)
      }
      .onReceive(dotsTimer) { _ in
        dots = dots.count < 3 ? dots + "." : ""
      }
  }
}

#Preview("Loading Indicator") {
  VStack(spacing: 20) {
    // Without token data
    LoadingIndicator(
      startTime: Date()
    )
    
    // With token data but no price
    LoadingIndicator(
      startTime: Date().addingTimeInterval(-5),
      inputTokens: 200,
      outputTokens: 29
    )
    
    // With token data and price (debug mode)
    LoadingIndicator(
      startTime: Date().addingTimeInterval(-15.7),
      inputTokens: 1000,
      outputTokens: 850,
      costUSD: 0.0234
    )
    
    // Force hide price even in debug
    LoadingIndicator(
      startTime: Date().addingTimeInterval(-10),
      inputTokens: 500,
      outputTokens: 400,
      costUSD: 0.0150,
      showPrice: false
    )
    
    // With token count hidden
    LoadingIndicator(
      startTime: Date().addingTimeInterval(-8),
      inputTokens: 750,
      outputTokens: 600,
      costUSD: 0.0180,
      showTokenCount: false
    )
  }
  .padding()
  .frame(width: 600)
}