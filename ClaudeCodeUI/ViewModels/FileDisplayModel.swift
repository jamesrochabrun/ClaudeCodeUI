//
//  FileDisplayModel.swift
//  ClaudeCodeUI
//
//  Created on 12/27/24.
//

import Foundation

/// A unified model for displaying file information in the UI
/// Can represent either an active file or a file with selection
struct FileDisplayModel: Identifiable {
    let id = UUID()
    let fileName: String
    let filePath: String
    let lineRange: ClosedRange<Int>?
    let isRemovable: Bool
    
    /// Creates a model for an active file
    static func activeFile(_ file: FileInfo) -> FileDisplayModel {
        FileDisplayModel(
            fileName: file.name,
            filePath: file.path,
            lineRange: nil,
            isRemovable: false
        )
    }
    
    /// Creates a model for a file selection
    static func selection(_ selection: TextSelection) -> FileDisplayModel {
        FileDisplayModel(
            fileName: selection.fileName,
            filePath: selection.filePath,
            lineRange: selection.lineRange,
            isRemovable: true
        )
    }
    
    /// Display text for the file (includes line range if present)
    var displayText: String {
        if let lineRange = lineRange {
            let lowerBound = lineRange.lowerBound + 1 // Convert to 1-based
            let upperBound = lineRange.upperBound + 1 // Convert to 1-based
            
            if lowerBound == upperBound {
                return "\(fileName) \(lowerBound)"
            } else {
                return "\(fileName) \(lowerBound)-\(upperBound)"
            }
        } else {
            return fileName
        }
    }
    
    var fileExtension: String {
        URL(fileURLWithPath: filePath).pathExtension.lowercased()
    }
}