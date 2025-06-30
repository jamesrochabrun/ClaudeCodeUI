//
//  AttachmentPreviewView.swift
//  ClaudeCodeUI
//
//  Created by Claude on 2025-06-30.
//

import SwiftUI

/// Displays a preview of an attachment with loading states and error handling
struct AttachmentPreviewView: View {
  let attachment: FileAttachment
  let onRemove: () -> Void
  
  @State private var isHovering = false
  @State private var showFullImage = false
  
  var body: some View {
    VStack(spacing: 4) {
      ZStack(alignment: .topTrailing) {
        // Main content
        Group {
          switch attachment.state {
          case .initial, .loading:
            LoadingView()
          case .ready(let content):
            ContentView(content: content, attachment: attachment)
              .onTapGesture {
                if case .image = content {
                  showFullImage = true
                }
              }
          case .error(let error):
            ErrorView(error: error)
          }
        }
        .frame(width: 80, height: 80)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(8)
        .overlay(
          RoundedRectangle(cornerRadius: 8)
            .stroke(Color(NSColor.separatorColor), lineWidth: 1)
        )
        
        // Remove button
        if isHovering {
          Button(action: onRemove) {
            Image(systemName: "xmark.circle.fill")
              .font(.system(size: 16))
              .foregroundColor(.white)
              .background(Circle().fill(Color.black.opacity(0.7)))
          }
          .buttonStyle(PlainButtonStyle())
          .offset(x: 8, y: -8)
          .transition(.opacity)
        }
      }
      .animation(.easeInOut(duration: 0.2), value: isHovering)
      .onHover { hovering in
        isHovering = hovering
      }
      
      // File name
      Text(attachment.fileName)
        .font(.caption)
        .lineLimit(1)
        .truncationMode(.middle)
        .frame(maxWidth: 80)
      
      // File size
      Text(attachment.formattedFileSize)
        .font(.caption2)
        .foregroundColor(.secondary)
    }
    .sheet(isPresented: $showFullImage) {
      if case .ready(.image(_, let base64URL, _)) = attachment.state {
        FullImageView(base64URL: base64URL, fileName: attachment.fileName)
      }
    }
  }
}

// MARK: - Content Views

private struct LoadingView: View {
  @State private var isAnimating = false
  
  var body: some View {
    ProgressView()
      .scaleEffect(0.7)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
      .onAppear {
        isAnimating = true
      }
  }
}

private struct ContentView: View {
  let content: AttachmentContent
  let attachment: FileAttachment
  
  var body: some View {
    switch content {
    case .image(_, _, let thumbnailBase64):
      if let thumbnail = thumbnailBase64,
         let imageData = Data(base64Encoded: thumbnail.replacingOccurrences(of: "data:image/png;base64,", with: "").replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
         let nsImage = NSImage(data: imageData) {
        Image(nsImage: nsImage)
          .resizable()
          .aspectRatio(contentMode: .fit)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        Image(systemName: "photo")
          .font(.title2)
          .foregroundColor(.secondary)
      }
      
    case .text(_, _):
      VStack {
        Image(systemName: attachment.type.systemImageName)
          .font(.title2)
          .foregroundColor(.secondary)
        Text(attachment.type.displayName)
          .font(.caption2)
          .foregroundColor(.secondary)
      }
      
    case .data(_, _):
      VStack {
        Image(systemName: "doc")
          .font(.title2)
          .foregroundColor(.secondary)
        Text("File")
          .font(.caption2)
          .foregroundColor(.secondary)
      }
    }
  }
}

private struct ErrorView: View {
  let error: AttachmentError
  
  var body: some View {
    VStack(spacing: 4) {
      Image(systemName: "exclamationmark.triangle")
        .font(.title2)
        .foregroundColor(.red)
      Text("Error")
        .font(.caption2)
        .foregroundColor(.red)
    }
  }
}

// MARK: - Full Image View

private struct FullImageView: View {
  let base64URL: String
  let fileName: String
  @Environment(\.dismiss) private var dismiss
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Text(fileName)
          .font(.headline)
        
        Spacer()
        
        Button("Close") {
          dismiss()
        }
        .keyboardShortcut(.escape, modifiers: [])
      }
      .padding()
      .background(Color(NSColor.windowBackgroundColor))
      
      Divider()
      
      // Image
      if let imageData = Data(base64Encoded: base64URL.replacingOccurrences(of: "data:image/png;base64,", with: "").replacingOccurrences(of: "data:image/jpeg;base64,", with: "")),
         let nsImage = NSImage(data: imageData) {
        ScrollView([.horizontal, .vertical]) {
          Image(nsImage: nsImage)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
      } else {
        Text("Failed to load image")
          .foregroundColor(.secondary)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      }
    }
    .frame(minWidth: 600, minHeight: 400)
  }
}

// MARK: - Attachment List View

/// Displays a horizontal scrolling list of attachments
struct AttachmentListView: View {
  @Binding var attachments: [FileAttachment]
  let processor = AttachmentProcessor()
  
  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(attachments) { attachment in
          AttachmentPreviewView(attachment: attachment) {
            withAnimation(.easeOut(duration: 0.2)) {
              attachments.removeAll { $0.id == attachment.id }
            }
          }
        }
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
    }
    .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
    .cornerRadius(8)
    .overlay(
      RoundedRectangle(cornerRadius: 8)
        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
    )
    .onAppear {
      // Process any unprocessed attachments
      Task {
        let unprocessedAttachments = attachments.filter { attachment in
          if case .initial = attachment.state {
            return true
          }
          return false
        }
        
        if !unprocessedAttachments.isEmpty {
          await processor.processAttachments(unprocessedAttachments)
        }
      }
    }
  }
}
