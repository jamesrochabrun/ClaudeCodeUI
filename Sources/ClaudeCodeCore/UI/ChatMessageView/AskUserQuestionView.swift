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
  @State private var focusedOptionIndex: Int = 0
  @FocusState private var isFocused: Bool

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
    .disabled(isSubmitting)
    .opacity(isSubmitting ? 0.5 : 1.0)
    .allowsHitTesting(!isSubmitting)
    .focusable()
    .focused($isFocused)
    .onKeyPress { key in
      handleArrowKeyPress(key)
    }
    .onAppear {
      isFocused = true
    }
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

  private var isOnSubmitStep: Bool {
    currentQuestionIndex == questionSet.questions.count
  }

  private var submitStepIndicator: some View {
    let canNavigateToSubmit = allQuestionsAnswered

    return Button(action: {
      if canNavigateToSubmit {
        navigateToSubmitStep()
      }
    }) {
      HStack(spacing: 6) {
        Image(systemName: canNavigateToSubmit ? "checkmark" : "arrow.right.circle")
          .font(.system(size: 11))
          .foregroundColor(canNavigateToSubmit ? .brandTertiary : .secondary.opacity(0.6))

        Text("Submit")
          .font(.system(size: 12, weight: isOnSubmitStep ? .semibold : .regular, design: .monospaced))
          .foregroundColor(isOnSubmitStep ? .primary : .secondary)
      }
      .padding(.horizontal, 10)
      .padding(.vertical, 6)
      .background(isOnSubmitStep ? Color.brandPrimary.opacity(0.15) : Color.clear)
      .cornerRadius(6)
      .overlay(
        RoundedRectangle(cornerRadius: 6)
          .stroke(isOnSubmitStep ? Color.brandPrimary.opacity(0.4) : Color.clear, lineWidth: 1)
      )
    }
    .buttonStyle(.plain)
    .disabled(!canNavigateToSubmit)
    .opacity(canNavigateToSubmit ? 1.0 : 0.5)
  }

  private func navigateToSubmitStep() {
    withAnimation(.easeInOut(duration: 0.25)) {
      currentQuestionIndex = questionSet.questions.count
    }
  }

  // MARK: - Question Content

  private var questionContent: some View {
    VStack(alignment: .leading, spacing: 0) {
      if isOnSubmitStep {
        submitStepContent
          .padding(16)
          .id("submit")
          .transition(.asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
          ))
      } else if currentQuestionIndex < questionSet.questions.count {
        let question = questionSet.questions[currentQuestionIndex]
        QuestionCardView(
          question: question,
          questionIndex: currentQuestionIndex,
          selectedOptions: binding(for: currentQuestionIndex, keyPath: \.selectedOptions),
          otherText: binding(for: currentQuestionIndex, keyPath: \.otherText),
          focusedOptionIndex: $focusedOptionIndex
        )
        .padding(16)
        .id(currentQuestionIndex)
        .transition(.asymmetric(
          insertion: .move(edge: .trailing).combined(with: .opacity),
          removal: .move(edge: .leading).combined(with: .opacity)
        ))
      }
    }
    .background(contentBackground)
    .clipped()
  }

  private var submitStepContent: some View {
    VStack(alignment: .leading, spacing: 16) {
      Text("Review your answers")
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.primary)

      // Summary of answers
      VStack(alignment: .leading, spacing: 10) {
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
      .padding(12)
      .background(Color(NSColor.controlBackgroundColor))
      .cornerRadius(8)

      Text("Press Return to submit or use arrow keys to go back and edit.")
        .font(.system(size: 11))
        .foregroundColor(.secondary)
    }
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
      if isOnSubmitStep {
        Text("Ready to submit")
          .font(.system(size: 11, design: .monospaced))
          .foregroundColor(.secondary)
      } else {
        Text("\(currentQuestionIndex + 1) of \(questionSet.questions.count)")
          .font(.system(size: 11, design: .monospaced))
          .foregroundColor(.secondary)
      }

      Spacer()

      // Next or Submit button
      if isOnSubmitStep {
        // Submit button on submit step
        Button(action: handleSubmit) {
          Text("Submit")
            .font(.system(size: 13, weight: .medium))
        }
        .buttonStyle(.borderedProminent)
        .tint(.brandPrimary)
        .disabled(isSubmitting)
      } else {
        // Next button (goes to submit step from last question)
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
    // Can advance to next question or to submit step (index = questions.count)
    if currentQuestionIndex < questionSet.questions.count && canAdvanceFromCurrent {
      withAnimation(.easeInOut(duration: 0.25)) {
        currentQuestionIndex += 1
      }
      // Only sync focus if not on submit step
      if currentQuestionIndex < questionSet.questions.count {
        syncFocusToSelection()
      }
    }
  }

  private func goToPreviousQuestion() {
    if currentQuestionIndex > 0 {
      withAnimation(.easeInOut(duration: 0.25)) {
        currentQuestionIndex -= 1
      }
      syncFocusToSelection()
    }
  }

  /// Syncs focusedOptionIndex to the currently selected option (if any)
  private func syncFocusToSelection() {
    guard currentQuestionIndex < questionSet.questions.count else { return }
    let question = questionSet.questions[currentQuestionIndex]
    let selected = answers[currentQuestionIndex]?.selectedOptions ?? []

    if let firstSelected = selected.first,
       let index = question.options.firstIndex(where: { $0.label == firstSelected }) {
      focusedOptionIndex = index
    } else {
      focusedOptionIndex = 0
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

  private func handleArrowKeyPress(_ key: KeyPress) -> KeyPress.Result {
    guard isExpanded && !isSubmitting else { return .ignored }

    // Handle submit step separately
    if isOnSubmitStep {
      switch key.key {
      case .leftArrow:
        goToPreviousQuestion()
        return .handled
      case .return:
        handleSubmit()
        return .handled
      default:
        return .ignored
      }
    }

    // Handle question steps
    guard currentQuestionIndex < questionSet.questions.count else { return .ignored }

    let currentQuestion = questionSet.questions[currentQuestionIndex]
    let optionCount = currentQuestion.options.count

    switch key.key {
    case .leftArrow:
      goToPreviousQuestion()
      return .handled
    case .rightArrow:
      if canAdvanceFromCurrent {
        goToNextQuestion()
        return .handled
      }
      return .ignored
    case .upArrow:
      // Wrap around: if at first option, go to last
      focusedOptionIndex = focusedOptionIndex > 0 ? focusedOptionIndex - 1 : optionCount - 1
      // For single-select, clear selection so only focus indicator shows
      if !currentQuestion.multiSelect {
        answers[currentQuestionIndex]?.selectedOptions.removeAll()
      }
      return .handled
    case .downArrow:
      // Wrap around: if at last option, go to first
      focusedOptionIndex = focusedOptionIndex < optionCount - 1 ? focusedOptionIndex + 1 : 0
      // For single-select, clear selection so only focus indicator shows
      if !currentQuestion.multiSelect {
        answers[currentQuestionIndex]?.selectedOptions.removeAll()
      }
      return .handled
    case .return:
      return handleReturnKey(currentQuestion: currentQuestion)
    default:
      return .ignored
    }
  }

  private func handleReturnKey(currentQuestion: Question) -> KeyPress.Result {
    let optionCount = currentQuestion.options.count

    // If we have a valid focused option, select it
    if focusedOptionIndex < optionCount {
      let option = currentQuestion.options[focusedOptionIndex]
      toggleOption(option.label, for: currentQuestion)

      // For single-select, auto-advance to next question (or to submit step)
      if !currentQuestion.multiSelect {
        goToNextQuestion()
      }
      return .handled
    }

    return .ignored
  }

  private func toggleOption(_ label: String, for question: Question) {
    // Clear "Other" text when selecting an option
    answers[currentQuestionIndex]?.otherText = ""

    if question.multiSelect {
      // Multi-select: toggle the option
      if answers[currentQuestionIndex]?.selectedOptions.contains(label) == true {
        answers[currentQuestionIndex]?.selectedOptions.remove(label)
      } else {
        answers[currentQuestionIndex]?.selectedOptions.insert(label)
      }
    } else {
      // Single-select: replace selection
      answers[currentQuestionIndex]?.selectedOptions.removeAll()
      answers[currentQuestionIndex]?.selectedOptions.insert(label)
    }
  }

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
  }
}
