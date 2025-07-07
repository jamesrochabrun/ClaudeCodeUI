//
//  FileDiff.swift
//  ClaudeCodeUI
//
//  Created by Assistant on 7/7/2025.
//

import Foundation
import SwiftUI
import TerminalServiceInterface
import os.log

// MARK: - Git Diff Generation

extension FileDiff {
    public static func getGitDiff(oldContent: String, newContent: String, terminalService: TerminalService) async throws -> String {
        let uuid = UUID().uuidString
        let tmpFileV0Path = "/tmp/file-0-\(uuid).txt"
        let tmpFileV1Path = "/tmp/file-1-\(uuid).txt"
        
        let fileManager = FileManager.default
        fileManager.createFile(
            atPath: tmpFileV0Path,
            contents: oldContent.formattedToApplyGitDiff.utf8Data,
            attributes: nil)
        fileManager.createFile(
            atPath: tmpFileV1Path,
            contents: newContent.formattedToApplyGitDiff.utf8Data,
            attributes: nil)
        
        defer {
            try? fileManager.removeItem(atPath: tmpFileV0Path)
            try? fileManager.removeItem(atPath: tmpFileV1Path)
        }
        
        let command = "git diff --no-index --no-color \(tmpFileV0Path) \(tmpFileV1Path)"
        let result = try await terminalService.runTerminal(command, quiet: true)
        
        // Git diff returns exit code 1 when there are differences, which is expected
        guard result.exitCode == 0 || result.exitCode == 1 else {
            throw DiffError.gitDiffFailed(result.errorOutput ?? "Unknown error")
        }
        
        let diff = (result.output ?? "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .dropFirst(4)  // Remove the file path headers
            .joined(separator: "\n")
        
        return diff.formatAppliedGitDiff
    }
}

// MARK: - Git Diff Parsing

extension FileDiff {
    static func gitDiffToChangedRanges(oldContent: String, newContent: String, diffText: String) -> [LineChange] {
        let newLines = newContent.splitLines()
        let newLinesOffset = offsetFor(lines: newLines)
        let oldLines = oldContent.splitLines()
        let oldLinesOffset = offsetFor(lines: oldLines)
        
        var result = [LineChange]()
        var removedLines = 0
        var addedLines = 0
        
        // Parse diff hunks
        let lines = diffText.split(separator: "\n", omittingEmptySubsequences: false)
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            
            // Check for hunk header
            if line.starts(with: "@@") {
                // Parse hunk header to get line numbers
                let hunkPattern = #/@@ -(\d+)(?:,(\d+))? \+(\d+)(?:,(\d+))? @@/#
                if let match = try? hunkPattern.firstMatch(in: String(line)) {
                    let addedLineOffset = Int(match.output.3) ?? 1
                    
                    // Add unchanged content before this hunk
                    while result.count - removedLines < addedLineOffset - 1 {
                        let idx = result.count - removedLines
                        if idx < newLines.count {
                            let range = newLinesOffset[idx]..<newLinesOffset[idx + 1]
                            result.append(LineChange(idx, range, String(newLines[idx]), .unchanged))
                        }
                    }
                }
                i += 1
                continue
            }
            
            // Process diff lines
            if line.starts(with: "+") {
                let idx = result.count - removedLines
                if idx < newLines.count {
                    let range = newLinesOffset[idx]..<newLinesOffset[idx + 1]
                    result.append(LineChange(idx, range, String(newLines[idx]), .added))
                    addedLines += 1
                }
            } else if line.starts(with: "-") {
                let idx = result.count - addedLines
                if idx < oldLines.count {
                    let range = oldLinesOffset[idx]..<oldLinesOffset[idx + 1]
                    result.append(LineChange(idx, range, String(oldLines[idx]), .removed))
                    removedLines += 1
                }
            } else if line.starts(with: " ") {
                let idx = result.count - removedLines
                if idx < newLines.count {
                    let range = newLinesOffset[idx]..<newLinesOffset[idx + 1]
                    result.append(LineChange(idx, range, String(newLines[idx]), .unchanged))
                }
            }
            
            i += 1
        }
        
        // Add remaining unchanged content
        while result.count - removedLines < newLines.count {
            let idx = result.count - removedLines
            let range = newLinesOffset[idx]..<newLinesOffset[idx + 1]
            result.append(LineChange(idx, range, String(newLines[idx]), .unchanged))
            addedLines += 1
        }
        
        return result
    }
    
    private static func offsetFor(lines: [String.SubSequence]) -> [Int] {
        var result: [Int] = []
        result.reserveCapacity(lines.count + 1)
        var offset = 0
        for l in lines {
            result.append(offset)
            offset += l.count
        }
        result.append(offset)
        return result
    }
}

// MARK: - Colored Diff Generation

extension FileDiff {
    public static func getColoredDiff(
        oldContent: String,
        newContent: String,
        terminalService: TerminalService,
        gitDiff: String? = nil) async throws -> FormattedFileChange
    {
        let diff: String
        if let gitDiff = gitDiff {
            diff = gitDiff
        } else {
            diff = try await getGitDiff(
                oldContent: oldContent,
                newContent: newContent,
                terminalService: terminalService
            )
        }
        
        let diffRanges = gitDiffToChangedRanges(
            oldContent: oldContent,
            newContent: newContent,
            diffText: diff
        )
        
        // For now, create attributed strings without syntax highlighting
        let oldContentFormatted = AttributedString(oldContent)
        let newContentFormatted = AttributedString(newContent)
        
        var formattedLineChanges: [FormattedLineChange] = []
        
        for lineChange in diffRanges {
            let formattedContent = lineChange.type == .removed ? oldContentFormatted : newContentFormatted
            guard let range = formattedContent.range(lineChange.characterRange) else {
                continue
            }
            let line = AttributedString(formattedContent[range])
            formattedLineChanges.append(FormattedLineChange(formattedContent: line, change: lineChange))
        }
        
        return FormattedFileChange(changes: formattedLineChanges)
    }
}

// MARK: - DiffError

enum DiffError: LocalizedError {
    case gitDiffFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .gitDiffFailed(let message):
            return "Git diff failed: \(message)"
        }
    }
}