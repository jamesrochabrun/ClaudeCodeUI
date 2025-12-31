//
//  AskUserQuestionView.swift
//  ClaudeCodeUI
//
//  Created for AskUserQuestion tool support
//

import SwiftUI

/// A view that displays questions in a step-by-step flow for the user to answer
public struct AskUserQuestionView: View {
  let messageId: UUID
  let questionSet: QuestionSet
  let viewModel: ChatViewModel
  let isResolved: Bool

  @State private var answers: [Int: QuestionAnswerState] = [:]
  @State private var currentQuestionIndex: Int = 0
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
      // Collapsible Header
      mainHeader

      Rectangle()
        .fill(borderColor)
        .frame(height: 1)

      if isExpanded {
        if !isResolved {
          // Step navigation header
          stepHeader

          Rectangle()
            .fill(borderColor)
            .frame(height: 1)

          // Current question content
          questionContent

          Rectangle()
            .fill(borderColor)
            .frame(height: 1)

          // Footer with navigation controls
          footerControls
        } else {
          // Show answered summary when resolved
          answeredSummary
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
    .animation(.easeInOut(duration: 0.2), value: currentQuestionIndex)
  }

  // MARK: - Main Header

  private var mainHeader: some View {
    HStack {
      Image(systemName: isResolved ? "checkmark.circle.fill" : "questionmark.circle.fill")
        .font(.system(size: 14))
        .foregroundColor(isResolved ? .brandTertiary : .brandPrimary)

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
  }

  // MARK: - Step Header

  private var stepHeader: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 4) {
        // Back navigation arrow
        navigationArrow(direction: .back)

        // Question step indicators
        ForEach(Array(questionSet.questions.enumerated()), id: \.offset) { index, question in
          stepIndicator(for: index, question: question)
        }

        // Submit indicator
        submitStepIndicator

        // Forward navigation arrow
        navigationArrow(direction: .forward)
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .background(stepHeaderBackground)
  }

  private func navigationArrow(direction: NavigationDirection) -> some View {
    let isBack = direction == .back
    let isEnabled = isBack ? currentQuestionIndex > 0 : canAdvanceFromCurrent

    return Button(action: {
      if isBack {
        goToPreviousQuestion()
      } else {
        goToNextQuestion()
      }
    }) {
      Image(systemName: isBack ? "chevron.left" : "chevron.right")
        .font(.system(size: 11, weight: .medium))
        .foregroundColor(isEnabled ? .brandPrimary : .secondary.opacity(0.4))
        .frame(width: 24, height: 24)
    }
    .buttonStyle(.plain)
    .disabled(!isEnabled)
  }

  private func stepIndicator(for index: Int, question: Question) -> some View {
    let isAnswered = hasAnsweredQuestion(at: index)
    let isCurrent = index == currentQuestionIndex
    let canNavigate = index <= currentQuestionIndex || (index == currentQuestionIndex + 1 && canAdvanceFromCurrent)

    return Button(action: {
      navigateToQuestion(index)
    }) {
      HStack(spacing: 6) {
        Image(systemName: isAnswered ? "checkmark.square.fill" : "square")
          .font(.system(size: 11))
          .foregroundColor(isAnswered ? .brandTertiary : .secondary.opacity(0.6))

        Text(question.header)
          .font(.system(size: 12, weight: isCurrent ? .semibold : .regular, design: .monospaced))
          .foregroundColor(isCurrent ? .primary : .secondary)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(isCurrent ? Color.brandPrimary.opacity(0.15) : Color.clear)
      .cornerRadius(6)
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(isCurrent ? Color.brandPrimary.opacity(0.4) : Color.clear, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(!canNavigate)
    .opacity(canNavigate ? 1.0 : 0.5)
  }

  private var submitStepIndicator: some View {
    let canSubmit = allQuestionsAnswered

    return HStack(spacing: 6) {
      Image(systemName: canSubmit ? "checkmark" : "arrow.right.circle")
        .font(.system(size: 11))
        .foregroundColor(canSubmit ? .brandTertiary : .secondary.opacity(0.6))

      Text("Submit")
        .font(.system(size: 12, weight: .regular, design: .monospaced))
        .foregroundColor(.secondary)
    }
    .padding(.horizontal, 10)
    .padding(.vertical, 6)
    .opacity(0.7)
  }

  // MARK: - Question Content

  private var questionContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      if currentQuestionIndex < questionSet.questions.count {
        let question = questionSet.questions[currentQuestionIndex]
        QuestionCardView(
          question: question,
          questionIndex: currentQuestionIndex,
          selectedOptions: binding(for: currentQuestionIndex, keyPath: \.selectedOptions),
          otherText: binding(for: currentQuestionIndex, keyPath: \.otherText)
        )
        .padding(16)
        .id(currentQuestionIndex) // Force view recreation for animation
        .transition(.asymmetric(
          insertion: .move(edge: .trailing).combined(with: .opacity),
          removal: .move(edge: .leading).combined(with: .opacity)
        ))
      }
    }
    .background(contentBackground)
    .clipped()
  }

  // MARK: - Footer Controls

  private var footerControls: some View {
    HStack {
      // Previous button
      Button(action: goToPreviousQuestion) {
        HStack(spacing: 4) {
          Image(systemName: "chevron.left")
          Text("Previous")
        }
        .font(.system(size: 13))
      }
      .buttonStyle(.plain)
      .foregroundColor(currentQuestionIndex > 0 ? .brandPrimary : .secondary.opacity(0.4))
      .disabled(currentQuestionIndex == 0)

      Spacer()

      // Progress indicator
      Text("\(currentQuestionIndex + 1) of \(questionSet.questions.count)")
        .font(.system(size: 11, design: .monospaced))
        .foregroundColor(.secondary)

      Spacer()

      // Next or Submit button
      if currentQuestionIndex == questionSet.questions.count - 1 {
        // Submit button (only enabled if all questions answered)
        Button(action: handleSubmit) {
          HStack(spacing: 6) {
            if isSubmitting {
              ProgressView()
                .controlSize(.small)
                .scaleEffect(0.8)
            }
            Text(isSubmitting ? "Submitting..." : "Submit")
              .font(.system(size: 13, weight: .medium))
          }
        }
        .buttonStyle(.borderedProminent)
        .tint(.brandPrimary)
        .disabled(!allQuestionsAnswered || isSubmitting)
      } else {
        // Next button
        Button(action: goToNextQuestion) {
          HStack(spacing: 4) {
            Text("Next")
            Image(systemName: "chevron.right")
          }
          .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(.borderedProminent)
        .tint(.brandPrimary)
        .disabled(!canAdvanceFromCurrent)
      }
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 12)
    .background(actionButtonBackground)
  }

  // MARK: - Answered Summary (when resolved)

  private var answeredSummary: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(Array(questionSet.questions.enumerated()), id: \.offset) { index, question in
        if let answerState = answers[index] {
          HStack(alignment: .top, spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
              .font(.system(size: 12))
              .foregroundColor(.brandTertiary)

            VStack(alignment: .leading, spacing: 2) {
              Text(question.header)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.primary)

              let answerText = formatAnswer(answerState)
              Text(answerText)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            }
          }
        }
      }
    }
    .padding(16)
    .background(contentBackground)
  }

  private func formatAnswer(_ state: QuestionAnswerState) -> String {
    var parts: [String] = Array(state.selectedOptions)
    if !state.otherText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      parts.append("Other: \(state.otherText)")
    }
    return parts.joined(separator: ", ")
  }

  // MARK: - Navigation Logic

  private enum NavigationDirection {
    case back, forward
  }

  private func hasAnsweredQuestion(at index: Int) -> Bool {
    guard let state = answers[index] else { return false }
    return !state.selectedOptions.isEmpty ||
           !state.otherText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }

  private var canAdvanceFromCurrent: Bool {
    hasAnsweredQuestion(at: currentQuestionIndex)
  }

  private var allQuestionsAnswered: Bool {
    for index in 0..<questionSet.questions.count {
      if !hasAnsweredQuestion(at: index) {
        return false
      }
    }
    return true
  }

  private func navigateToQuestion(_ index: Int) {
    // Can always go back
    if index < currentQuestionIndex {
      withAnimation(.easeInOut(duration: 0.25)) {
        currentQuestionIndex = index
      }
      return
    }

    // Can only advance if current question is answered
    if index == currentQuestionIndex + 1 && canAdvanceFromCurrent {
      withAnimation(.easeInOut(duration: 0.25)) {
        currentQuestionIndex = index
      }
    }
  }

  private func goToNextQuestion() {
    if currentQuestionIndex < questionSet.questions.count - 1 && canAdvanceFromCurrent {
      withAnimation(.easeInOut(duration: 0.25)) {
        currentQuestionIndex += 1
      }
    }
  }

  private func goToPreviousQuestion() {
    if currentQuestionIndex > 0 {
      withAnimation(.easeInOut(duration: 0.25)) {
        currentQuestionIndex -= 1
      }
    }
  }

  // MARK: - Helpers

  private func binding<T>(for index: Int, keyPath: WritableKeyPath<QuestionAnswerState, T>) -> Binding<T> {
    Binding(
      get: { answers[index, default: QuestionAnswerState()][keyPath: keyPath] },
      set: { answers[index, default: QuestionAnswerState()][keyPath: keyPath] = $0 }
    )
  }

  // MARK: - Styling

  private var headerBackground: Color {
    let baseColor = isResolved ? Color.brandTertiary.opacity(0.15) : Color.brandPrimary.opacity(0.1)
    return colorScheme == .dark ? baseColor : baseColor.opacity(0.8)
  }

  private var stepHeaderBackground: Color {
    colorScheme == .dark
      ? Color(white: 0.08)
      : Color(white: 0.96)
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
      return Color.brandTertiary.opacity(0.3)
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
