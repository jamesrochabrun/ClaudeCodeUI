//
//  InlineVoiceModeViewWrapper.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 11/28/25.
//

import CodeWhisper
import SwiftUI

/// Wrapper around InlineVoiceModeView that observes ChatViewModel for assistant responses.
/// For sttWithTTS mode, orchestrates two phases:
/// 1. STT phase: Show STTModeView, record and transcribe, dismiss after sending message
/// 2. TTS phase: Wait for assistant response, show TTSModeView to speak it, then dismiss
@MainActor
public struct InlineVoiceModeViewWrapper: View {

  // MARK: - Voice Phase

  enum VoicePhase {
    case stt       // Recording/transcribing
    case waiting   // Waiting for assistant response (view hidden)
    case tts       // Speaking assistant response
  }

  // MARK: - Dependencies

  @Environment(ChatViewModel.self) private var chatViewModel

  // MARK: - Configuration

  let mode: VoiceMode
  let height: CGFloat
  let ttsSpeaker: TTSSpeaker
  @Binding var stopRecordingAction: (() -> Void)?
  let onTranscription: ((String) -> Void)?
  let onDismiss: (() -> Void)?

  // MARK: - State

  @State private var currentPhase: VoicePhase = .stt
  @State private var transcribedText: String = ""
  @State private var lastSpokenMessageId: UUID?
  @State private var waitingForResponse: Bool = false
  @State private var userMessageIndex: Int = 0
  @State private var settingsManager = SettingsManager()
  @State private var serviceManager = OpenAIServiceManager()

  // MARK: - Computed Properties

  /// Tracks when assistant messages become complete (for onChange detection)
  private var completedAssistantMessageCount: Int {
    chatViewModel.messages.filter { $0.role == .assistant && $0.isComplete }.count
  }

  // MARK: - Initialization

  public init(
    mode: VoiceMode = .sttWithTTS,
    height: CGFloat = 42,
    ttsSpeaker: TTSSpeaker,
    stopRecordingAction: Binding<(() -> Void)?> = .constant(nil),
    onTranscription: ((String) -> Void)? = nil,
    onDismiss: (() -> Void)? = nil
  ) {
    self.mode = mode
    self.height = height
    self.ttsSpeaker = ttsSpeaker
    self._stopRecordingAction = stopRecordingAction
    self.onTranscription = onTranscription
    self.onDismiss = onDismiss
  }

  // MARK: - Body

  public var body: some View {
    Group {
      if mode == .sttWithTTS {
        // Orchestrate STT → waiting → TTS phases
        sttWithTTSBody
      } else {
        // For other modes, just pass through to InlineVoiceModeView
        InlineVoiceModeView(
          mode: mode,
          height: height,
          transcribedText: $transcribedText,
          stopRecordingAction: $stopRecordingAction,
          onTranscription: handleTranscription,
          onDismiss: onDismiss,
          ttsSpeaker: ttsSpeaker
        )
        .environment(settingsManager)
        .environment(serviceManager)
      }
    }
    .onAppear {
      serviceManager.updateService(apiKey: settingsManager.apiKey)
    }
    .onChange(of: settingsManager.apiKey) { _, newValue in
      serviceManager.updateService(apiKey: newValue)
    }
    .onChange(of: chatViewModel.messages.count) { _, _ in
      if waitingForResponse {
        checkForAssistantResponse()
      }
    }
    .onChange(of: completedAssistantMessageCount) { _, _ in
      // Also check when any assistant message becomes complete
      if waitingForResponse {
        checkForAssistantResponse()
      }
    }
    .onChange(of: ttsSpeaker.state) { _, newState in
      // When TTS finishes speaking, dismiss completely
      if currentPhase == .tts && !newState.isSpeaking {
        onDismiss?()
      }
    }
  }

  // MARK: - STT with TTS Body

  @ViewBuilder
  private var sttWithTTSBody: some View {
    switch currentPhase {
    case .stt:
      // Use regular .stt mode - it dismisses properly after transcription
      InlineVoiceModeView(
        mode: .stt,
        height: height,
        transcribedText: $transcribedText,
        stopRecordingAction: $stopRecordingAction,
        onTranscription: handleTranscription,
        onDismiss: handleSTTDismiss
      )
      .environment(settingsManager)
      .environment(serviceManager)

    case .waiting:
      // Hidden, waiting for assistant response
      EmptyView()

    case .tts:
      // Show TTS visualization while speaking
      ttsView
    }
  }

  // MARK: - TTS View

  private var ttsView: some View {
    HStack(spacing: 8) {
      // Stop button
      Button {
        ttsSpeaker.stop()
        onDismiss?()
      } label: {
        ZStack {
          Circle()
            .fill(Color.green.opacity(0.8))
            .frame(width: 28, height: 28)
          RoundedRectangle(cornerRadius: 2)
            .fill(Color.white)
            .frame(width: 10, height: 10)
        }
      }
      .buttonStyle(.plain)
      .help("Stop speaking")

      // TTS Visualizer
      WaveformBarsView(
        waveformLevels: deriveTTSWaveform(ttsSpeaker.audioLevel),
        barColor: .green.opacity(0.8),
        isActive: true
      )
      .frame(height: height - 16)
    }
    .padding(.horizontal, 12)
    .padding(.vertical, 4)
    .background {
      Capsule()
        .fill(.ultraThinMaterial)
    }
  }

  private func deriveTTSWaveform(_ audioLevel: Float) -> [Float] {
    (0..<8).map { index in
      let variation = Float(sin(Double(index) * 0.6 + Double(audioLevel) * 8) * 0.3 + 0.7)
      return min(1.0, audioLevel * variation)
    }
  }

  // MARK: - Phase Transitions

  private func handleSTTDismiss() {
    if mode == .sttWithTTS {
      // Transition to waiting phase (view hidden, waiting for response)
      currentPhase = .waiting
    } else {
      // Regular mode - just dismiss
      onDismiss?()
    }
  }

  // MARK: - Message Handling

  private func handleTranscription(_ text: String) {
    // Mark where we are in the message list before user message is sent
    userMessageIndex = chatViewModel.messages.count
    waitingForResponse = true

    // Call the parent's onTranscription callback
    // The existing system will send this as a user message to Claude
    onTranscription?(text)
  }

  private func checkForAssistantResponse() {
    // Find the first assistant text message AFTER the user message index
    let messagesAfterUser = chatViewModel.messages.dropFirst(userMessageIndex)
    guard let assistantMessage = messagesAfterUser.first(where: {
      $0.role == .assistant && $0.messageType == .text
    }) else {
      return
    }

    // Only speak if complete and not already spoken
    guard assistantMessage.isComplete,
          assistantMessage.id != lastSpokenMessageId,
          !assistantMessage.content.isEmpty else {
      return
    }

    lastSpokenMessageId = assistantMessage.id
    waitingForResponse = false

    // Transition to TTS phase and start speaking
    currentPhase = .tts
    ttsSpeaker.speak(text: assistantMessage.content)
  }
}

// MARK: - Previews

#Preview("STT with TTS Mode") {
  InlineVoiceModeViewWrapper(
    mode: .sttWithTTS,
    ttsSpeaker: TTSSpeaker(),
    onTranscription: { text in
      print("User said: \(text)")
    }
  )
  .frame(height: 50)
  .padding()
  .background(Color.black)
}
