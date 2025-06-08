//
//  RootView.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 5/25/25.
//

import SwiftUI
import ClaudeCodeSDK

struct RootView: View {
  
  @State var viewModel = ChatViewModel(claudeClient: ClaudeCodeClient(debug: true))
  
  var body: some View {
    ChatScreen(viewModel: viewModel)
  }
}

#Preview {
  RootView()
}
