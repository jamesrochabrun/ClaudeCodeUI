//
//  AskUserQuestionView.swift
//  ClaudeCodeUI
//
//  Created for AskUserQuestion tool support
//

import SwiftUI

/// A view that displays multiple questions for the user to answer
public struct AskUserQuestionView: View {
  let messageId: UUID
  let questionSet: QuestionSet
  let viewModel: ChatViewModel
  let isResolved: Bool
  
  @State private var answers: [Int: QuestionAnswerState] = [:]
  @State private var isSubmitting = false
  @State private var isExpanded = true
  
  @Environment(\.colorScheme) private var colorScheme
  
  // Track answer state for each question
  struct QuestionAnswerState {
    var selectedOptions: Set<String> = []
    var otherText: String = ""
  }
  
  public init(
    messageId: UUID,
    questionSet: QuestionSet,
    viewModel: ChatViewModel,
    isResolved: Bool = false
  ) {
    self.messageId = messageId
    self.questionSet = questionSet
    self.viewModel = viewModel
    self.isResolved = isResolved
    
    // Initialize answer state for each question
    var initialAnswers: [Int: QuestionAnswerState] = [:]
    for (index, _) in questionSet.questions.enumerated() {
      initialAnswers[index] = QuestionAnswerState()
    }
    _answers = State(initialValue: initialAnswers)
  }
  
  public var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      // Header
      HStack {
        Image(systemName: isResolved ? "checkmark.circle.fill" : "questionmark.circle.fill")
          .font(.system(size: 14))
          .foregroundColor(isResolved ? .green : .blue)
        
        Text(isResolved ? "Questions Answered" : "Questions")
          .font(.system(size: 13, weight: .medium))
          .foregroundColor(.primary)
        
        Text("(\(questionSet.questions.count))")
          .font(.system(size: 12))
          .foregroundColor(.secondary)
        
        Spacer()
        
        Button(action: {
          withAnimation(.easeInOut(duration: 0.2)) {
            isExpanded.toggle()
          }
        }) {
          Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.system(size: 11))
            .foregroundColor(.secondary)
        }
        .buttonStyle(.plain)
      }
      .padding(.horizontal, 14)
      .padding(.vertical, 10)
      .background(headerBackground)
      
      // Divider
      Rectangle()
        .fill(borderColor)
        .frame(height: 1)
      
      if isExpanded {
        // Questions content
        ScrollView {
          VStack(alignment: .leading, spacing: 16) {
            ForEach(Array(questionSet.questions.enumerated()), id: \.offset) { index, question in
              QuestionCardView(
                question: question,
                questionIndex: index,
                selectedOptions: binding(for: index, keyPath: \.selectedOptions),
                otherText: binding(for: index, keyPath: \.otherText)
              )
            }
          }
          .padding(16)
        }
        .frame(maxHeight: 500)
        .background(contentBackground)
        
        // Only show submit button if not resolved
        if !isResolved {
          // Divider before submit button
          Rectangle()
            .fill(borderColor)
            .frame(height: 1)
          
          // Submit button
          HStack {
            Spacer()
            
            Button(action: {
              handleSubmit()
            }) {
              HStack(spacing: 6) {
                if isSubmitting {
                  ProgressView()
                    .controlSize(.small)
                    .scaleEffect(0.8)
                }
                
                Text(isSubmitting ? "Submitting..." : "Submit Answers")
                  .font(.system(size: 13, weight: .medium))
              }
              .padding(.horizontal, 16)
              .padding(.vertical, 8)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!isValidToSubmit || isSubmitting)
          }
          .padding(12)
          .background(actionButtonBackground)
        }
      }
    }
    .background(Color(NSColor.controlBackgroundColor))
    .cornerRadius(10)
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(borderColor, lineWidth: 1)
    )
    .animation(.easeInOut(duration: 0.2), value: isExpanded)
  }
  
  // MARK: - Helpers
  
  private func binding<T>(for index: Int, keyPath: WritableKeyPath<QuestionAnswerState, T>) -> Binding<T> {
    Binding(
      get: { answers[index, default: QuestionAnswerState()][keyPath: keyPath] },
      set: { answers[index, default: QuestionAnswerState()][keyPath: keyPath] = $0 }
    )
  }
  
  private var isValidToSubmit: Bool {
    // Check that each question has at least one answer
    for (index, _) in questionSet.questions.enumerated() {
      guard let answerState = answers[index] else { return false }
      
      let hasSelectedOptions = !answerState.selectedOptions.isEmpty
      let hasOtherText = !answerState.otherText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
      
      if !hasSelectedOptions && !hasOtherText {
        return false
      }
    }
    return true
  }
  
  // MARK: - Styling
  
  private var headerBackground: Color {
    let baseColor = isResolved ? Color.green.opacity(0.15) : Color.blue.opacity(0.1)
    return colorScheme == .dark ? baseColor : baseColor.opacity(0.8)
  }
  
  private var contentBackground: Color {
    colorScheme == .dark
    ? Color(NSColor.controlBackgroundColor).opacity(0.5)
    : Color(white: 0.98)
  }
  
  private var actionButtonBackground: Color {
    colorScheme == .dark
    ? Color(white: 0.12)
    : Color(white: 0.98)
  }
  
  private var borderColor: Color {
    if isResolved {
      return Color.green.opacity(0.3)
    }
    return colorScheme == .dark
    ? Color(white: 0.25)
    : Color(white: 0.85)
  }
  
  // MARK: - Action Handlers
  
  private func handleSubmit() {
    isSubmitting = true
    
    // Collect all answers
    var questionAnswers: [QuestionAnswer] = []
    
    for (index, _) in questionSet.questions.enumerated() {
      guard let answerState = answers[index] else { continue }
      
      var selectedLabels = Array(answerState.selectedOptions)
      var otherText: String? = nil
      
      // If user provided "Other" text, include it
      if !answerState.otherText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
        otherText = answerState.otherText
        // Add a marker for "Other" if no options were selected
        if selectedLabels.isEmpty {
          selectedLabels.append("Other")
        }
      }
      
      questionAnswers.append(QuestionAnswer(
        questionIndex: index,
        selectedLabels: selectedLabels,
        otherText: otherText
      ))
    }
    
    // Submit answers via the view model
    viewModel.submitQuestionAnswers(
      toolUseId: questionSet.toolUseId,
      answers: questionAnswers,
      messageId: messageId
    )
    
    // The submission will trigger a continuation of the conversation
    // Reset submitting state after a brief delay
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
      isSubmitting = false
    }
  }
}
