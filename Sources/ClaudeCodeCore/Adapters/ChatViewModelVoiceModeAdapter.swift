//
//  ChatViewModelVoiceModeAdapter.swift
//  ClaudeCodeCore
//
//  Adapter that makes ChatViewModel conform to VoiceModeChatInterface protocol.
//  This enables voice mode to work with ChatViewModel without direct coupling,
//  using Combine publishers for message observation.
//

import Combine
import CodeWhisper
import Foundation

/// Adapter that wraps ChatViewModel to conform to VoiceModeChatInterface protocol.
/// Uses Combine publishers to notify voice mode of assistant message completions.
@MainActor
public final class ChatViewModelVoiceModeAdapter: VoiceModeChatInterface {
  
  // MARK: - Private Properties
  
  private weak var chatViewModel: ChatViewModel?
  private var cancellables = Set<AnyCancellable>()
  
  // Subjects for publishing state changes
  private let assistantMessageSubject = PassthroughSubject<VoiceModeMessage, Never>()
  private let executingSubject = CurrentValueSubject<Bool, Never>(false)
  
  // Track last completed message to avoid duplicates
  private var lastCompletedMessageId: UUID?
  
  // Track observation timer
  private var observationTimer: AnyCancellable?
  
  // MARK: - VoiceModeChatInterface Publishers
  
  public var assistantMessageCompletedPublisher: AnyPublisher<VoiceModeMessage, Never> {
    assistantMessageSubject.eraseToAnyPublisher()
  }
  
  public var isExecutingPublisher: AnyPublisher<Bool, Never> {
    executingSubject.eraseToAnyPublisher()
  }
  
  // MARK: - VoiceModeChatInterface State
  
  public var isExecuting: Bool {
    chatViewModel?.isLoading ?? false
  }
  
  public var workingDirectory: String? {
    chatViewModel?.projectPath
  }
  
  // MARK: - Initialization
  
  public init(chatViewModel: ChatViewModel) {
    self.chatViewModel = chatViewModel
    setupObservation()
  }
  
  deinit {
    observationTimer?.cancel()
  }
  
  // MARK: - VoiceModeChatInterface Actions
  
  public func sendVoiceMessage(_ text: String) {
    guard let viewModel = chatViewModel else { return }
    viewModel.sendMessage(text, context: nil, hiddenContext: nil, codeSelections: nil, attachments: nil)
  }
  
  public func cancelExecution() {
    chatViewModel?.cancelRequest()
  }
  
  // MARK: - Private Methods
  
  private func setupObservation() {
    guard chatViewModel != nil else { return }
    
    // Use a timer-based polling approach since ChatViewModel uses @Observable
    // This bridges @Observable to Combine publishers
    observationTimer = Timer.publish(every: 0.1, on: .main, in: .common)
      .autoconnect()
      .sink { [weak self] _ in
        self?.checkForCompletedMessages()
        self?.updateExecutingState()
      }
  }
  
  private func checkForCompletedMessages() {
    guard let viewModel = chatViewModel else { return }
    
    // Find completed assistant text messages
    let completedAssistantMessages = viewModel.messages.filter { message in
      message.role == .assistant &&
      message.messageType == .text &&
      message.isComplete &&
      !message.content.isEmpty
    }
    
    // Check if there's a new completed message
    guard let latestMessage = completedAssistantMessages.last,
          latestMessage.id != lastCompletedMessageId else {
      return
    }
    
    // Update tracking and emit
    lastCompletedMessageId = latestMessage.id
    
    let voiceMessage = VoiceModeMessage(
      id: latestMessage.id,
      role: .assistant,
      content: latestMessage.content,
      isComplete: true,
      timestamp: latestMessage.timestamp
    )
    
    assistantMessageSubject.send(voiceMessage)
  }
  
  private func updateExecutingState() {
    guard let viewModel = chatViewModel else { return }
    let newValue = viewModel.isLoading
    if executingSubject.value != newValue {
      executingSubject.send(newValue)
    }
  }
}
