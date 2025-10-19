//
//  AskUserQuestionModels.swift
//  ClaudeCodeUI
//
//  Created for AskUserQuestion tool support
//

import Foundation

/// Represents a single option within a question
public struct QuestionOption: Codable, Equatable, Identifiable, Sendable {
		public let id: UUID

		/// The display text for this option
		public let label: String

		/// Explanation of what this option means
		public let description: String

		public init(id: UUID = UUID(), label: String, description: String) {
				self.id = id
				self.label = label
				self.description = description
		}
}

/// Represents a single question with its options
public struct Question: Codable, Equatable, Identifiable, Sendable {
		public let id: UUID

		/// The complete question text
		public let question: String

		/// Short label for display (max 12 chars)
		public let header: String

		/// Available options for this question
		public let options: [QuestionOption]

		/// Whether multiple selections are allowed
		public let multiSelect: Bool

		public init(
				id: UUID = UUID(),
				question: String,
				header: String,
				options: [QuestionOption],
				multiSelect: Bool
		) {
				self.id = id
				self.question = question
				self.header = header
				self.options = options
				self.multiSelect = multiSelect
		}
}

/// Represents a set of questions from an AskUserQuestion tool call
public struct QuestionSet: Codable, Equatable, Sendable {
		/// The questions to be answered
		public let questions: [Question]

		/// The tool use ID for sending back the response
		public let toolUseId: String

		public init(questions: [Question], toolUseId: String) {
				self.questions = questions
				self.toolUseId = toolUseId
		}
}

/// Represents a user's answer to a question
public struct QuestionAnswer: Codable, Equatable, Sendable {
		/// Index of the question being answered
		public let questionIndex: Int

		/// Selected option labels (can be multiple for multiSelect)
		public let selectedLabels: [String]

		/// Custom text if "Other" was selected
		public let otherText: String?

		public init(questionIndex: Int, selectedLabels: [String], otherText: String? = nil) {
				self.questionIndex = questionIndex
				self.selectedLabels = selectedLabels
				self.otherText = otherText
		}
}
