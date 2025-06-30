//
//  FileAttachment.swift
//  ClaudeCodeUI
//
//  Created by Claude on 2025-06-30.
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// MARK: - Attachment Type
public enum AttachmentType: String, CaseIterable, Codable {
  case image = "image"
  case pdf = "pdf"
  case text = "text"
  case markdown = "markdown"
  case code = "code"
  case other = "other"
  
  var displayName: String {
    switch self {
    case .image: return "Image"
    case .pdf: return "PDF"
    case .text: return "Text"
    case .markdown: return "Markdown"
    case .code: return "Code"
    case .other: return "Other"
    }
  }
  
  var systemImageName: String {
    switch self {
    case .image: return "photo"
    case .pdf: return "doc.richtext"
    case .text: return "doc.text"
    case .markdown: return "doc.text.fill"
    case .code: return "chevron.left.forwardslash.chevron.right"
    case .other: return "doc"
    }
  }
  
  static func from(url: URL) -> AttachmentType {
    guard let utType = UTType(filenameExtension: url.pathExtension) else {
      return .other
    }
    
    if utType.conforms(to: .image) {
      return .image
    } else if utType.conforms(to: .pdf) {
      return .pdf
    } else if url.pathExtension == "md" {
      return .markdown
    } else if utType.conforms(to: .sourceCode) || isCodeExtension(url.pathExtension) {
      return .code
    } else if utType.conforms(to: .text) {
      return .text
    } else {
      return .other
    }
  }
  
  private static func isCodeExtension(_ ext: String) -> Bool {
    let codeExtensions = ["swift", "js", "ts", "jsx", "tsx", "py", "java", "cpp", "c", "h", "m", "mm", "go", "rs", "rb", "php", "cs", "sh", "yaml", "yml", "json", "xml", "html", "css", "scss", "sql"]
    return codeExtensions.contains(ext.lowercased())
  }
}

// MARK: - Attachment State
public enum AttachmentState: Equatable {
  case initial
  case loading
  case ready(content: AttachmentContent)
  case error(AttachmentError)
}

// MARK: - Attachment Content
public enum AttachmentContent: Equatable {
  case image(path: String, base64URL: String, thumbnailBase64: String?)
  case text(path: String, content: String)
  case data(path: String, base64: String)
}

// MARK: - Attachment Error
public enum AttachmentError: LocalizedError, Equatable {
  case fileNotFound
  case invalidFileType
  case fileTooLarge(maxSize: Int64)
  case encodingFailed
  case readingFailed
  case unsupportedFormat
  
  public var errorDescription: String? {
    switch self {
    case .fileNotFound:
      return "File not found"
    case .invalidFileType:
      return "Invalid file type"
    case .fileTooLarge(let maxSize):
      let formatter = ByteCountFormatter()
      return "File too large. Maximum size: \(formatter.string(fromByteCount: maxSize))"
    case .encodingFailed:
      return "Failed to encode file"
    case .readingFailed:
      return "Failed to read file"
    case .unsupportedFormat:
      return "Unsupported file format"
    }
  }
}

// MARK: - File Attachment Model
@Observable
public class FileAttachment: Identifiable {
  public let id = UUID()
  public let url: URL
  public let type: AttachmentType
  public let fileName: String
  public let fileSize: Int64?
  public var state: AttachmentState = .initial
  public let createdAt = Date()
  public let isTemporary: Bool // Track if this is a temporary file (screenshot/clipboard)
  
  // Maximum file sizes
  static let maxImageSize: Int64 = 20 * 1024 * 1024 // 20MB
  static let maxDocumentSize: Int64 = 10 * 1024 * 1024 // 10MB
  
  public init(url: URL, isTemporary: Bool = false) {
    self.url = url
    self.type = AttachmentType.from(url: url)
    self.fileName = url.lastPathComponent
    self.fileSize = try? FileManager.default.attributesOfItem(atPath: url.path)[.size] as? Int64
    self.isTemporary = isTemporary
  }
  
  // Validate file size
  public func validateSize() -> AttachmentError? {
    guard let size = fileSize else { return nil }
    
    switch type {
    case .image:
      if size > Self.maxImageSize {
        return .fileTooLarge(maxSize: Self.maxImageSize)
      }
    case .pdf, .text, .markdown, .code:
      if size > Self.maxDocumentSize {
        return .fileTooLarge(maxSize: Self.maxDocumentSize)
      }
    default:
      break
    }
    
    return nil
  }
  
  // Get file size formatted string
  public var formattedFileSize: String {
    guard let size = fileSize else { return "Unknown size" }
    let formatter = ByteCountFormatter()
    formatter.countStyle = .file
    return formatter.string(fromByteCount: size)
  }
  
  // Check if attachment is ready
  public var isReady: Bool {
    if case .ready = state {
      return true
    }
    return false
  }
  
  // Get attachment content for API
  public var apiContent: String? {
    guard case .ready(let content) = state else { return nil }
    
    switch content {
    case .image(let path, _, _):
      return path
    case .text(let path, _):
      return path
    case .data(let path, _):
      return path
    }
  }
  
  // Get attachment path
  public var filePath: String? {
    guard case .ready(let content) = state else { return nil }
    
    switch content {
    case .image(let path, _, _), .text(let path, _), .data(let path, _):
      return path
    }
  }
  
  // Get base64 content for UI display
  public var displayContent: String? {
    guard case .ready(let content) = state else { return nil }
    
    switch content {
    case .image(_, let base64URL, _):
      return base64URL
    case .text(_, let textContent):
      return textContent
    case .data(_, let base64):
      return "data:application/octet-stream;base64,\(base64)"
    }
  }
}

// MARK: - Attachment Collection
@Observable
public class AttachmentCollection {
  public var attachments: [FileAttachment] = []
  
  public init() {}
  
  public func add(_ attachment: FileAttachment) {
    attachments.append(attachment)
  }
  
  public func remove(_ attachment: FileAttachment) {
    attachments.removeAll { $0.id == attachment.id }
  }
  
  public func removeAll() {
    attachments.removeAll()
  }
  
  public var hasAttachments: Bool {
    !attachments.isEmpty
  }
  
  public var totalSize: Int64 {
    attachments.compactMap { $0.fileSize }.reduce(0, +)
  }
  
  public var allReady: Bool {
    attachments.allSatisfy { $0.isReady }
  }
}
