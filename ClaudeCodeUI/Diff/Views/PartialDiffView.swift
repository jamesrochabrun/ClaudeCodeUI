//
//  PartialDiffView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import SwiftUI

struct PartialDiffView: View {
    let changedLines: [FormattedLineChange]
    let partialRange: Range<Int>
    
    @State private var lineHeight: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme
    
    private enum Constants {
        static let fontSize: CGFloat = 11
    }
    
    var body: some View {
        HoverReader { hoveringPosition in
            ZStack(alignment: .topLeading) {
                background
                Text(content)
                    .font(Font.custom("Menlo", fixedSize: Constants.fontSize))
                    .fixedSize()
                    .textSelection(.enabled)
                    .padding(.horizontal, 5)
                    .readingSize { newValue in
                        if partialRange.count > 0 {
                            lineHeight = newValue.height / CGFloat(partialRange.count)
                        }
                    }
            }
        }
    }
    
    @ViewBuilder
    private var background: some View {
        VStack(spacing: 0) {
            ForEach(partialRange, id: \.self) { i in
                Rectangle()
                    .fill(backgroundColor(for: changedLines[i]))
                    .frame(height: lineHeight)
            }
        }
    }
    
    private var content: AttributedString {
        var result = AttributedString()
        for i in partialRange {
            guard i < changedLines.count else { continue }
            let line = changedLines[i].formattedContent
            
            if i == partialRange.upperBound - 1 && line.characters.last == "\n" {
                // Remove last newline
                let endIndex = line.index(line.endIndex, offsetByCharacters: -1)
                result.append(AttributedString(line[line.startIndex..<endIndex]))
            } else {
                result.append(line)
            }
        }
        return result
    }
    
    private func backgroundColor(for line: FormattedLineChange) -> Color {
        switch line.change.type {
        case .added:
            return colorScheme.addedLineDiffBackground
        case .removed:
            return colorScheme.removedLineDiffBackground
        case .unchanged:
            return Color.clear
        }
    }
}