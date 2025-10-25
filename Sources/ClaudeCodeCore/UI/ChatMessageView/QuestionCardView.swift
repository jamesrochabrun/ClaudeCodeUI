//
//  QuestionCardView.swift
//  ClaudeCodeUI
//
//  Created for AskUserQuestion tool support
//

import SwiftUI

/// A card view for displaying a single question with its options
struct QuestionCardView: View {
  let question: Question
  let questionIndex: Int
  @Binding var selectedOptions: Set<String>
  @Binding var otherText: String
  
  @Environment(\.colorScheme) private var colorScheme
  @State private var isOtherSelected = false
  
  var body: some View {
    VStack(alignment: .leading, spacing: 12) {
      // Header chip
      HStack {
        Text(question.header)
          .font(.system(size: 11, weight: .medium))
          .foregroundColor(.white)
          .padding(.horizontal, 8)
          .padding(.vertical, 4)
          .background(Color.blue)
          .cornerRadius(4)
        
        Spacer()
      }
      
      // Question text
      Text(question.question)
        .font(.system(size: 14, weight: .medium))
        .foregroundColor(.primary)
        .fixedSize(horizontal: false, vertical: true)
      
      // Options
      VStack(alignment: .leading, spacing: 8) {
        ForEach(question.options) { option in
          optionView(option)
        }
      }
      
      // "Other" text field (always visible)
      VStack(alignment: .leading, spacing: 6) {
        Text("Other:")
          .font(.system(size: 12, weight: .medium))
          .foregroundColor(.secondary)
        
        TextField("Enter custom response...", text: $otherText)
          .textFieldStyle(.plain)
          .font(.system(size: 13))
          .padding(8)
          .background(Color(NSColor.controlBackgroundColor))
          .cornerRadius(6)
          .overlay(
            RoundedRectangle(cornerRadius: 6)
              .stroke(Color(NSColor.separatorColor), lineWidth: 0.5)
          )
          .onChange(of: otherText) { _, newValue in
            // If user types in "Other", mark it as selected
            if !newValue.isEmpty {
              isOtherSelected = true
              if !question.multiSelect {
                // For single select, clear other options
                selectedOptions.removeAll()
              }
            } else {
              isOtherSelected = false
            }
          }
      }
    }
    .padding(16)
    .background(cardBackground)
    .cornerRadius(10)
    .overlay(
      RoundedRectangle(cornerRadius: 10)
        .stroke(borderColor, lineWidth: 1)
    )
  }
  
  @ViewBuilder
  private func optionView(_ option: QuestionOption) -> some View {
    let isSelected = selectedOptions.contains(option.label)
    
    Button(action: {
      toggleOption(option.label)
    }) {
      HStack(alignment: .top, spacing: 12) {
        // Selection indicator
        if question.multiSelect {
          // Checkbox for multi-select
          Image(systemName: isSelected ? "checkmark.square.fill" : "square")
            .font(.system(size: 16))
            .foregroundColor(isSelected ? .blue : .secondary)
        } else {
          // Radio button for single-select
          Image(systemName: isSelected ? "circle.fill" : "circle")
            .font(.system(size: 16))
            .foregroundColor(isSelected ? .blue : .secondary)
        }
        
        VStack(alignment: .leading, spacing: 4) {
          Text(option.label)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.primary)
            .fixedSize(horizontal: false, vertical: true)
          
          Text(option.description)
            .font(.system(size: 12))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
        
        Spacer()
      }
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .padding(10)
    .background(isSelected ? selectionBackground : Color.clear)
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(isSelected ? Color.blue.opacity(0.5) : Color.clear, lineWidth: 1.5)
    )
  }
  
  private func toggleOption(_ label: String) {
    // Clear "Other" text when selecting an option
    otherText = ""
    isOtherSelected = false
    
    if question.multiSelect {
      // Multi-select: toggle the option
      if selectedOptions.contains(label) {
        selectedOptions.remove(label)
      } else {
        selectedOptions.insert(label)
      }
    } else {
      // Single-select: replace selection
      selectedOptions.removeAll()
      selectedOptions.insert(label)
    }
  }
  
  // MARK: - Styling
  
  private var cardBackground: Color {
    colorScheme == .dark
    ? Color(NSColor.controlBackgroundColor)
    : Color.white
  }
  
  private var selectionBackground: Color {
    colorScheme == .dark
    ? Color.blue.opacity(0.15)
    : Color.blue.opacity(0.08)
  }
  
  private var borderColor: Color {
    colorScheme == .dark
    ? Color(white: 0.25)
    : Color(white: 0.85)
  }
}
