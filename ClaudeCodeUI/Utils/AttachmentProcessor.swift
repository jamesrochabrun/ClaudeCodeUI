//
//  AttachmentProcessor.swift
//  ClaudeCodeUI
//
//  Created by Claude on 2025-06-30.
//

import Foundation
import AppKit
import PDFKit
import CoreImage

/// Handles processing of file attachments including base64 conversion, image resizing, and text extraction
public actor AttachmentProcessor {
  
  // Maximum dimensions for resized images
  private let maxImageDimension: CGFloat = 500
  
  // Compression quality for JPEG images
  private let compressionQuality: CGFloat = 0.8
  
  // Thumbnail size for preview
  private let thumbnailSize = CGSize(width: 100, height: 100)
  
  /// Process a file attachment and update its state
  public func process(_ attachment: FileAttachment) async {
    attachment.state = .loading
    
    // Validate file size first
    if let error = attachment.validateSize() {
      attachment.state = .error(error)
      return
    }
    
    do {
      switch attachment.type {
      case .image:
        let content = try await processImage(at: attachment.url)
        attachment.state = .ready(content: content)
        
      case .pdf:
        let content = try await processPDF(at: attachment.url)
        attachment.state = .ready(content: content)
        
      case .text, .markdown, .code, .json, .xml, .yaml:
        let content = try await processTextFile(at: attachment.url)
        attachment.state = .ready(content: content)
        
      case .archive, .video, .audio, .spreadsheet, .presentation, .document:
        // For binary files, just provide file info without encoding
        let content = try await processGenericFile(at: attachment.url, skipEncoding: true)
        attachment.state = .ready(content: content)
        
      case .other:
        // For other file types, provide basic file info
        let content = try await processGenericFile(at: attachment.url, skipEncoding: true)
        attachment.state = .ready(content: content)
      }
    } catch {
      attachment.state = .error(.readingFailed)
    }
  }
  
  // MARK: - Image Processing
  
  private func processImage(at url: URL) async throws -> AttachmentContent {
    guard let image = NSImage(contentsOf: url) else {
      throw AttachmentError.invalidFileType
    }
    
    // Resize image if needed
    let resizedImage = resizeImageIfNeeded(image, maxDimension: maxImageDimension)
    
    // Convert to base64
    guard let base64URL = imageToBase64URL(resizedImage) else {
      throw AttachmentError.encodingFailed
    }
    
    // Generate thumbnail
    let thumbnail = resizeImageIfNeeded(image, maxDimension: thumbnailSize.width)
    let thumbnailBase64 = imageToBase64URL(thumbnail)
    
    // Return with file path
    return .image(path: url.path, base64URL: base64URL, thumbnailBase64: thumbnailBase64)
  }
  
  private func resizeImageIfNeeded(_ image: NSImage, maxDimension: CGFloat) -> NSImage {
    let originalSize = image.size
    
    // Check if resizing is needed
    if originalSize.width <= maxDimension && originalSize.height <= maxDimension {
      return image
    }
    
    // Calculate new size maintaining aspect ratio
    let scale = min(maxDimension / originalSize.width, maxDimension / originalSize.height)
    let newSize = CGSize(
      width: originalSize.width * scale,
      height: originalSize.height * scale
    )
    
    // Create resized image
    let newImage = NSImage(size: newSize)
    newImage.lockFocus()
    defer { newImage.unlockFocus() }
    
    image.draw(
      in: NSRect(origin: .zero, size: newSize),
      from: NSRect(origin: .zero, size: originalSize),
      operation: .sourceOver,
      fraction: 1.0
    )
    
    return newImage
  }
  
  private func imageToBase64URL(_ image: NSImage) -> String? {
    guard let tiffData = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiffData) else {
      return nil
    }
    
    // Try PNG first for better quality
    if let pngData = bitmap.representation(using: .png, properties: [:]) {
      return dataToBase64URL(pngData, mimeType: "image/png")
    }
    
    // Fall back to JPEG
    if let jpegData = bitmap.representation(
      using: .jpeg,
      properties: [.compressionFactor: compressionQuality]
    ) {
      return dataToBase64URL(jpegData, mimeType: "image/jpeg")
    }
    
    return nil
  }
  
  private func dataToBase64URL(_ data: Data, mimeType: String) -> String {
    let base64String = data.base64EncodedString()
    return "data:\(mimeType);base64,\(base64String)"
  }
  
  // MARK: - PDF Processing
  
  private func processPDF(at url: URL) async throws -> AttachmentContent {
    guard let document = PDFDocument(url: url) else {
      throw AttachmentError.invalidFileType
    }
    
    var extractedText = ""
    let pageCount = min(document.pageCount, 50) // Limit to first 50 pages
    
    for pageIndex in 0..<pageCount {
      if let page = document.page(at: pageIndex),
         let pageContent = page.string {
        extractedText += "Page \(pageIndex + 1):\n\(pageContent)\n\n"
      }
    }
    
    if extractedText.isEmpty {
      // If no text could be extracted, return as base64 data
      let data = try Data(contentsOf: url)
      return .data(path: url.path, base64: data.base64EncodedString())
    }
    
    return .text(path: url.path, content: extractedText)
  }
  
  // MARK: - Text File Processing
  
  private func processTextFile(at url: URL) async throws -> AttachmentContent {
    let content = try String(contentsOf: url, encoding: .utf8)
    return .text(path: url.path, content: content)
  }
  
  // MARK: - Generic File Processing
  
  private func processGenericFile(at url: URL, skipEncoding: Bool = false) async throws -> AttachmentContent {
    if skipEncoding {
      // For binary files, just return the file path without encoding
      // This avoids encoding large binary files that won't be useful as base64
      return .data(path: url.path, base64: "")
    } else {
      let data = try Data(contentsOf: url)
      return .data(path: url.path, base64: data.base64EncodedString())
    }
  }
  
  // MARK: - Batch Processing
  
  /// Process multiple attachments concurrently
  public func processAttachments(_ attachments: [FileAttachment]) async {
    await withTaskGroup(of: Void.self) { group in
      for attachment in attachments {
        group.addTask {
          await self.process(attachment)
        }
      }
    }
  }
}


// MARK: - XML Content Formatting

extension AttachmentProcessor {
  
  /// Format attachment content for inclusion in XML-tagged message
  public static func formatAttachmentForXML(_ attachment: FileAttachment) -> String? {
    guard case .ready(let content) = attachment.state else { return nil }
    
    switch content {
    case .image(let path, _, _):
      return """
            <IMAGE>
                <PATH>\(path)</PATH>
                <NAME>\(attachment.fileName)</NAME>
                <TYPE>\(attachment.isTemporary ? "screenshot" : "file")</TYPE>
            </IMAGE>
            """
      
    case .text(let path, let textContent):
      if attachment.type == .code {
        return """
                <CODE>
                    <PATH>\(path)</PATH>
                    <NAME>\(attachment.fileName)</NAME>
                    <LANGUAGE>\(attachment.url.pathExtension)</LANGUAGE>
                    <CONTENT>\(textContent)</CONTENT>
                </CODE>
                """
      } else {
        return """
                <DOCUMENT>
                    <PATH>\(path)</PATH>
                    <NAME>\(attachment.fileName)</NAME>
                    <CONTENT>\(textContent)</CONTENT>
                </DOCUMENT>
                """
      }
      
    case .data(let path, _):
      return """
            <FILE>
                <PATH>\(path)</PATH>
                <NAME>\(attachment.fileName)</NAME>
                <TYPE>\(attachment.type.rawValue)</TYPE>
            </FILE>
            """
    }
  }
  
  /// Format multiple attachments for XML
  public static func formatAttachmentsForXML(_ attachments: [FileAttachment]) -> String {
    let formattedAttachments = attachments.compactMap { formatAttachmentForXML($0) }
    
    if formattedAttachments.isEmpty {
      return ""
    }
    
    return """
        
        <ATTACHMENTS>
        \(formattedAttachments.joined(separator: "\n\n"))
        </ATTACHMENTS>
        """
  }
  
  /// Format image paths for inclusion in message text
  public static func formatImagePathsForMessage(_ attachments: [FileAttachment]) -> String? {
    let imagePaths = attachments.compactMap { attachment -> String? in
      guard attachment.type == .image,
            let path = attachment.filePath else { return nil }
      return "Analyze this image: \(path)"
    }
    
    return imagePaths.isEmpty ? nil : imagePaths.joined(separator: "\n")
  }
}
