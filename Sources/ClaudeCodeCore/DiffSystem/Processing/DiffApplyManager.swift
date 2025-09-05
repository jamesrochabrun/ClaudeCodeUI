//
//  DiffApplyManager.swift
//  ClaudeCodeUI
//
//  Created by James Rochabrun on 9/3/25.
//

import Foundation

// MARK: - DiffApplyManager

struct DiffApplyManager {
  
  /// Parses an XML string containing multiple DIFF blocks into an array of CodeDiff objects
  /// - Parameter xmlString: XML string containing DIFF blocks with SEARCH, REPLACE, and optional DESCRIPTION tags
  /// - Returns: Array of successfully parsed CodeDiff objects (malformed blocks are skipped)
  func parseDiffsIn(_ xmlString: String) -> [CodeDiff] {
    let normalizedXML = normalizeLineEndings(xmlString)
    let diffBlocks = extractDiffBlocks(from: normalizedXML)
    
    return diffBlocks.compactMap { parseDiffBlock($0) }
  }
  
  /// Demonstrate the complete process of applying diffs to a code file
  /// - Parameter combinedXML: XML string containing both code file and diffs
  /// - Returns: The updated code file content
  func processXML(_ combinedXML: String) -> String? {
    // Extract the code file
    guard let codeFile = parseCodeFile(combinedXML) else {
      AppLogger.error("Error: Could not extract code file")
      return nil
    }
    
    // Parse the diffs
    let diffs = parseDiffsIn(combinedXML)
    if diffs.isEmpty {
      AppLogger.info("Warning: No diffs found to apply")
      return codeFile
    }
    
    // Apply the diffs to the code file
    return apply(diffs: diffs, to: codeFile)
  }
  
  
  /// Applies a sequence of diffs to a code file
  /// - Parameters:
  ///   - diffs: Array of CodeDiff objects to apply
  ///   - codeFile: The original code file content
  /// - Returns: The updated code file content with all diffs applied
  func apply(
    diffs: [CodeDiff],
    to codeFile: String)
  -> String
  {
    var updatedCode = codeFile
    
    for diff in diffs {
      updatedCode = applyDiff(diff, to: updatedCode)
    }
    return updatedCode
  }
}


extension DiffApplyManager {
  
  /// Applies a single diff to the code
  /// - Parameters:
  ///   - diff: The CodeDiff object containing search pattern and replacement
  ///   - code: The current state of the code
  /// - Returns: The updated code with the diff applied
  private func applyDiff(_ diff: CodeDiff, to code: String) -> String {
    var updatedCode = code
    
    // Handle short patterns that might be ambiguous
    if diff.hasShortPattern {
      if let lastRange = findLastOccurrence(of: diff.searchPattern, in: updatedCode) {
        updatedCode.replaceSubrange(lastRange, with: diff.replacement)
        return updatedCode
      }
    }
    
    // Try standard pattern matching
    if let range = findAndValidatePattern(diff.searchPattern, in: updatedCode, diffDescription: diff.description) {
      updatedCode.replaceSubrange(range, with: diff.replacement)
      return updatedCode
    }
    
    // Fallback: Try with trimmed pattern
    if let range = tryTrimmedPattern(diff, in: updatedCode) {
      updatedCode.replaceSubrange(range, with: diff.replacement)
    }
    
    return updatedCode
  }
  
  /// Find the last occurrence of a pattern in a string
  private func findLastOccurrence(of pattern: String, in text: String) -> Range<String.Index>? {
    var lastRange: Range<String.Index>? = nil
    var searchStart = text.startIndex
    
    while searchStart < text.endIndex {
      if let range = text.range(of: pattern, range: searchStart..<text.endIndex) {
        lastRange = range
        searchStart = range.upperBound
      } else {
        break
      }
    }
    
    return lastRange
  }
  
  /// Finds a pattern in the code and validates its uniqueness
  /// - Parameters:
  ///   - pattern: The search pattern to find
  ///   - code: The code to search in
  ///   - diffDescription: Optional description of the diff for logging
  /// - Returns: The range of the first occurrence if found, nil otherwise
  private func findAndValidatePattern(_ pattern: String, in code: String, diffDescription: String?) -> Range<String.Index>? {
    guard let range = code.range(of: pattern) else {
      AppLogger.info("Warning: Could not find exact pattern for diff: \(diffDescription ?? "")")
      return nil
    }
    
    validatePatternUniqueness(pattern, in: code, diffDescription: diffDescription)
    return range
  }
  
  
  /// Validates if a pattern is unique in the code and logs warnings for multiple occurrences
  /// - Parameters:
  ///   - pattern: The pattern to validate
  ///   - code: The code to check for uniqueness
  ///   - diffDescription: Optional description of the diff for logging
  private func validatePatternUniqueness(_ pattern: String, in code: String, diffDescription: String?) {
    let occurrences = countOccurrences(of: pattern, in: code)
    
    if occurrences > 1 {
      let context = pattern.count > 50 ? "Search pattern" : "Trimmed search pattern"
      AppLogger.info("Warning: \(context) is not unique. Found \(occurrences) occurrences for diff: \(diffDescription ?? "")")
    }
  }
  
  /// Counts the number of occurrences of a pattern in the code
  /// - Parameters:
  ///   - pattern: The pattern to count
  ///   - code: The code to search in
  /// - Returns: The number of occurrences found
  private func countOccurrences(of pattern: String, in code: String) -> Int {
    return code.components(separatedBy: pattern).count - 1
  }
  
}

extension DiffApplyManager {
  
  private func parseCodeFile(_ xmlString: String) -> String? {
    extractContent(
      from: xmlString,
      startTag: "<code_file>",
      endTag: "</code_file>"
    )
  }
  
  /// Attempts to find a pattern after trimming whitespace as a fallback strategy
  /// - Parameters:
  ///   - diff: The CodeDiff object containing the search pattern
  ///   - code: The code to search in
  /// - Returns: The range of the trimmed pattern if found, nil otherwise
  private func tryTrimmedPattern(_ diff: CodeDiff, in code: String) -> Range<String.Index>? {
    let trimmedPattern = diff.searchPattern.trimmingCharacters(in: .whitespacesAndNewlines)
    
    guard let trimmedRange = code.range(of: trimmedPattern) else {
      AppLogger.info("Could not find pattern even after trimming whitespace")
      return nil
    }
    
    AppLogger.info("Found pattern after trimming whitespace")
    validatePatternUniqueness(trimmedPattern, in: code, diffDescription: diff.description)
    
    return trimmedRange
  }
  
  // MARK: - XML Normalization
  
  /// Normalizes line endings in the XML string to ensure consistent parsing
  /// - Parameter xmlString: The raw XML string that may contain mixed line endings
  /// - Returns: XML string with all line endings normalized to \n
  private func normalizeLineEndings(_ xmlString: String) -> String {
    return xmlString
      .replacingOccurrences(of: "\r\n", with: "\n")
      .replacingOccurrences(of: "\r", with: "\n")
  }
  
  // MARK: - Diff Block Extraction
  
  /// Extracts individual DIFF blocks from the normalized XML
  /// - Parameter xml: The normalized XML string containing DIFF tags
  /// - Returns: Array of strings, each representing a DIFF block's content
  private func extractDiffBlocks(from xml: String) -> [String] {
    return Array(xml.components(separatedBy: "<DIFF").dropFirst())
  }
  
  // MARK: - Diff Block Parsing
  
  /// Parses a single DIFF block into a CodeDiff object
  /// - Parameter diffBlock: A string containing a single DIFF block with its content and attributes
  /// - Returns: A CodeDiff object if parsing succeeds, nil for malformed blocks
  private func parseDiffBlock(_ diffBlock: String) -> CodeDiff? {
    guard let closingTagRange = diffBlock.range(of: "</DIFF>") else {
      return nil
    }
    
    let diffContentWithAttributes = String(diffBlock[..<closingTagRange.lowerBound])
    
    guard let closingBracketRange = diffContentWithAttributes.range(of: ">") else {
      return nil
    }
    
    let externalID = extractIDAttribute(from: diffContentWithAttributes)
    let diffContent = String(diffContentWithAttributes[closingBracketRange.upperBound...])
    
    return createCodeDiff(from: diffContent, withID: externalID)
  }
  
  // MARK: - Attribute Extraction
  
  /// Extracts the ID attribute value from a DIFF tag's opening element
  /// - Parameter content: The DIFF block content including the opening tag with attributes
  /// - Returns: The ID value if present, nil otherwise
  private func extractIDAttribute(from content: String) -> String? {
    guard content.contains("id=") else {
      return nil
    }
    
    guard let idRange = content.range(of: "id=\"([^\"]+)\"", options: .regularExpression) else {
      return nil
    }
    
    return extractQuotedValue(from: String(content[idRange]))
  }
  
  /// Extracts the value between quotes from an attribute string
  /// - Parameter idString: A string containing an attribute like id="value"
  /// - Returns: The value between the quotes, nil if quotes are malformed
  private func extractQuotedValue(from idString: String) -> String? {
    guard let startQuote = idString.firstIndex(of: "\""),
          let endQuote = idString.lastIndex(of: "\""),
          startQuote != endQuote else {
      return nil
    }
    
    return String(idString[idString.index(after: startQuote)..<endQuote])
  }
  
  // MARK: - Content Extraction
  
  /// Creates a CodeDiff object by extracting SEARCH, REPLACE, and DESCRIPTION tags from the content
  /// - Parameters:
  ///   - content: The inner content of a DIFF block (after the opening tag)
  ///   - externalID: Optional ID attribute extracted from the DIFF tag
  /// - Returns: A CodeDiff object if both SEARCH and REPLACE are found, nil otherwise
  private func createCodeDiff(from content: String, withID externalID: String?) -> CodeDiff? {
    guard let searchPattern = extractContent(from: content, startTag: "<SEARCH>", endTag: "</SEARCH>"),
          let replacement = extractContent(from: content, startTag: "<REPLACE>", endTag: "</REPLACE>") else {
      return nil
    }
    
    let description = extractContent(from: content, startTag: "<DESCRIPTION>", endTag: "</DESCRIPTION>")
    
    return CodeDiff(
      externalID,
      find: searchPattern,
      replace: replacement,
      note: description
    )
  }
  
  /// Extract content between specified tags, with automatic whitespace handling
  private func extractContent(from text: String, startTag: String, endTag: String) -> String? {
    guard
      let startRange = text.range(of: startTag),
      let endRange = text.range(of: endTag, range: startRange.upperBound..<text.endIndex)
    else {
      return nil
    }
    
    return String(text[startRange.upperBound..<endRange.lowerBound])
  }
}

// MARK: Helpers

extension DiffApplyManager {
  
  static func extractAllDiffContent(from input: String) -> String {
    // Define the regex pattern to match <DIFF> tags with attributes
    let pattern = "<DIFF[^>]*>[\\s\\S]*?</DIFF>"
    
    // Create a regular expression object
    guard let regex = try? NSRegularExpression(pattern: pattern) else {
      return ""
    }
    
    // Search for matches in the input string
    let nsRange = NSRange(input.startIndex..<input.endIndex, in: input)
    let matches = regex.matches(in: input, range: nsRange)
    
    // Extract all matched content
    let diffBlocks = matches.compactMap { match -> String? in
      let matchRange = match.range
      if let range = Range(matchRange, in: input) {
        return String(input[range])
      }
      return nil
    }
    
    // Combine all diff blocks into a single string
    return diffBlocks.joined(separator: "\n\n")
  }
}
