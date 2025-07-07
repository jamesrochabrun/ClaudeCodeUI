//
//  DiffView.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import SwiftUI

public struct DiffView: View {
    let formattedDiff: FormattedFileChange?
    let fileName: String?
    
    @Environment(\.colorScheme) private var colorScheme
    @State private var desiredTextWidth: CGFloat = 0
    @State private var isExpanded = true
    
    private enum Constants {
        static let maxUnchangedLinesContent = 3
    }
    
    public init(formattedDiff: FormattedFileChange?, fileName: String? = nil) {
        self.formattedDiff = formattedDiff
        self.fileName = fileName
    }
    
    private var changedLines: [FormattedLineChange] {
        formattedDiff?.changes ?? []
    }
    
    private var partialDiffRanges: [Range<Int>] {
        changedLines.changedSection(minSeparation: Constants.maxUnchangedLinesContent)
    }
    
    private var statistics: (additions: Int, deletions: Int) {
        let additions = changedLines.filter { $0.change.type == .added }.count
        let deletions = changedLines.filter { $0.change.type == .removed }.count
        return (additions, deletions)
    }
    
    public var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            diffHeader
            
            if isExpanded {
                content
                    .background(colorScheme.xcodeEditorBackground)
                    .cornerRadius(4)
            }
        }
    }
    
    @ViewBuilder
    private var diffHeader: some View {
        HStack {
            Button(action: { isExpanded.toggle() }) {
                HStack(spacing: 4) {
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 10))
                    
                    if let fileName = fileName {
                        Label(fileName, systemImage: "doc.text")
                            .font(.system(.body, design: .monospaced))
                    } else {
                        Text("Diff")
                            .font(.system(.body, design: .monospaced))
                    }
                    
                    // Statistics
                    let stats = statistics
                    HStack(spacing: 8) {
                        Text("+\(stats.additions)")
                            .foregroundColor(.green)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                        
                        Text("-\(stats.deletions)")
                            .foregroundColor(.red)
                            .font(.system(size: 12, weight: .medium, design: .monospaced))
                    }
                    .padding(.horizontal, 8)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.gray.opacity(0.1))
        .cornerRadius(4)
    }
    
    @ViewBuilder
    private var content: some View {
        // Measure desired width
        VStack(alignment: .leading) {
            ForEach(partialDiffRanges, id: \.id) { range in
                PartialDiffView(
                    changedLines: changedLines,
                    partialRange: range
                )
            }
        }
        .readSize(.init(get: { .zero }, set: { desiredTextWidth = $0.width }))
        
        // Actual content
        ScrollView([.horizontal, .vertical]) {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(zip(partialDiffRanges.indices, partialDiffRanges)), id: \.1.id) { idx, range in
                    if idx != 0 {
                        HStack {
                            Rectangle()
                                .frame(width: 10, height: 1)
                                .foregroundColor(.gray.opacity(0.7))
                            Text(hiddenLineText(idx: idx))
                                .font(.caption2)
                                .foregroundColor(.gray.opacity(0.7))
                            Rectangle()
                                .frame(height: 1)
                                .foregroundColor(.gray.opacity(0.7))
                        }
                        .frame(height: 15)
                    }
                    PartialDiffView(
                        changedLines: changedLines,
                        partialRange: range
                    )
                }
            }
            .frame(minWidth: desiredTextWidth)
            .padding(.vertical, 5)
        }
        .frame(maxHeight: 400)
    }
    
    private func hiddenLineText(idx: Int) -> String {
        let n = partialDiffRanges[idx].lowerBound - partialDiffRanges[idx - 1].upperBound
        return "\(n) hidden line\(n == 1 ? "" : "s")"
    }
}