//
//  ChatScreen+MessagesList.swift
//  ClaudeCodeUI
//
//  Created on 12/19/24.
//

import SwiftUI

extension ChatScreen {
  
  /// Enum to represent different types of message items after grouping
  enum MessageItem: Identifiable {
    case single(ChatMessage)
    case taskGroup(taskMessage: ChatMessage, groupedMessages: [ChatMessage])
    
    var id: UUID {
      switch self {
      case .single(let message):
        return message.id
      case .taskGroup(let taskMessage, _):
        return taskMessage.id
      }
    }
  }
  
  /// Groups messages by taskGroupId for display
  var groupedMessageItems: [MessageItem] {
    var items: [MessageItem] = []
    var processedIds = Set<UUID>()
    var taskGroups: [UUID: (task: ChatMessage, messages: [ChatMessage])] = [:]
    
    // First pass: identify all task groups
    for message in viewModel.messages {
      if let groupId = message.taskGroupId {
        if message.isTaskContainer {
          // This is the Task message that starts the group
          taskGroups[groupId] = (task: message, messages: [])
        } else if var group = taskGroups[groupId] {
          // Add to existing group
          group.messages.append(message)
          taskGroups[groupId] = group
        }
      }
    }
    
    // Second pass: create message items
    for message in viewModel.messages {
      // Skip if already processed as part of a group
      if processedIds.contains(message.id) {
        continue
      }
      
      if let groupId = message.taskGroupId,
         message.isTaskContainer,
         let group = taskGroups[groupId] {
        // Include ALL messages in the group
        items.append(.taskGroup(taskMessage: message, groupedMessages: group.messages))
        
        processedIds.insert(message.id)
        // Mark ALL messages in the group as processed
        for groupedMessage in group.messages {
          processedIds.insert(groupedMessage.id)
        }
      } else if message.taskGroupId == nil {
        // Regular message not part of any group
        items.append(.single(message))
        processedIds.insert(message.id)
      }
    }
    
    return items
  }
  
  /// Determines the effective working directory based on manual selection or global default
  var effectiveWorkingDirectory: String? {
    // First priority: manually set project path for the session
    if !viewModel.projectPath.isEmpty {
      return "cwd: \(viewModel.projectPath)"
    }

    // Second priority: global default working directory
    if !globalPreferences.defaultWorkingDirectory.isEmpty {
      return "cwd: \(globalPreferences.defaultWorkingDirectory)"
    }

    return nil
  }
  
  /// Determines whether to show the settings button
  var shouldShowSettingsButton: Bool {
    // Show settings button when there's no working directory
    return effectiveWorkingDirectory == nil
  }
  
  var messagesListView: some View {
    ScrollViewReader { scrollView in
      List {
        // Always show WelcomeRow at the top
        WelcomeRow(
          path: effectiveWorkingDirectory,
          showSettingsButton: shouldShowSettingsButton,
          appName: uiConfiguration.appName,
          toolTip: uiConfiguration.workingDirectoryToolTip,
          generalInstructionsTip: uiConfiguration.generalInstructionsTip,
          appIconAssetName: uiConfiguration.appIconAssetName,
          hasMessages: !viewModel.messages.isEmpty,
          onSettingsTapped: {
            settingsTypeToShow = .session
            showingSettings = true
          },
          onWorktreeSelected: { worktreePath in
            // Update the current session's working directory to the selected worktree
            viewModel.claudeClient.configuration.workingDirectory = worktreePath
            viewModel.projectPath = worktreePath
            viewModel.settingsStorage.setProjectPath(worktreePath)
          }
        )
        .listRowSeparator(.hidden)
        .id("welcome-row")
        
        // Group messages and display them
        ForEach(groupedMessageItems) { item in
          switch item {
          case .single(let message):
            ChatMessageView(
              message: message,
              settingsStorage: viewModel.settingsStorage,
              terminalService: terminalService,
              fontSize: 13.0,  // Default font size for now
              viewModel: viewModel,
              showArtifact: { artifactItem in
                artifact = artifactItem
              }
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .id(message.id)
            
          case .taskGroup(let taskMessage, let groupedMessages):
            TaskGroupView(
              taskMessage: taskMessage,
              groupedMessages: groupedMessages,
              settingsStorage: viewModel.settingsStorage,
              terminalService: terminalService,
              fontSize: 13.0,
              showArtifact: { artifactItem in
                artifact = artifactItem
              }
            )
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .id(taskMessage.id)
          }
        }
      }
      .listStyle(.plain)
      .listRowBackground(Color.clear)
      .scrollContentBackground(.hidden)
      .onChange(of: viewModel.messages) { _,_ in
        // Scroll to bottom when new messages are added
        if let lastMessage = viewModel.messages.last {
          withAnimation {
            scrollView.scrollTo(lastMessage.id, anchor: .bottom)
          }
        }
      }
      .onChange(of: globalPreferences.defaultWorkingDirectory) { _, _ in
        // Update the current session's working directory if there's no session-specific path
        let newDefault = globalPreferences.defaultWorkingDirectory
        if viewModel.projectPath.isEmpty && !newDefault.isEmpty {
          // Update all components to use the new default directory
          viewModel.projectPath = newDefault
          viewModel.claudeClient.configuration.workingDirectory = newDefault
          viewModel.settingsStorage.setProjectPath(newDefault)
        }
      }
    }
  }
}
