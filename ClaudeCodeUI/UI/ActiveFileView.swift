//
//  ActiveFileView.swift
//  ClaudeCodeUI
//
//  Created on 12/27/24.
//

import SwiftUI

struct ActiveFileView: View {
    let model: FileDisplayModel
    var onRemove: (() -> Void)? = nil
    
    var fileExtension: String {
        model.fileExtension
    }
    
    var languageIcon: (name: String, color: Color) {
        switch fileExtension {
        case "swift":
            return ("swift", .orange)
        case "js", "jsx":
            return ("curlybraces", .yellow)
        case "ts", "tsx":
            return ("curlybraces", .blue)
        case "py":
            return ("chevron.left.forwardslash.chevron.right", .green)
        case "java":
            return ("cup.and.saucer", .orange)
        case "c", "cpp", "cc", "cxx", "h", "hpp":
            return ("c.circle", .blue)
        case "cs":
            return ("number", .purple)
        case "go":
            return ("g.circle", .cyan)
        case "rs":
            return ("r.circle", .orange)
        case "rb":
            return ("diamond", .red)
        case "php":
            return ("p.circle", .indigo)
        case "html", "htm":
            return ("chevron.left.forwardslash.chevron.right", .orange)
        case "css", "scss", "sass":
            return ("number", .pink)
        case "json":
            return ("curlybraces", .gray)
        case "xml":
            return ("chevron.left.forwardslash.chevron.right", .gray)
        case "md", "markdown":
            return ("doc.text", .gray)
        case "sh", "bash", "zsh":
            return ("terminal", .gray)
        case "yml", "yaml":
            return ("doc.text", .purple)
        default:
            return ("doc", .gray)
        }
    }
    
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: languageIcon.name)
                .foregroundColor(languageIcon.color)
                .font(.system(size: 12))
            
            Text(model.displayText)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .truncationMode(.middle)
            
            if model.isRemovable, let onRemove = onRemove {
                Button(action: onRemove) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary.opacity(0.6))
                        .font(.system(size: 12))
                }
                .buttonStyle(.plain)
                .help("Remove from context")
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(Color.secondary.opacity(0.1))
        .cornerRadius(12)
        .help(model.isRemovable ? "Remove from context" : "Click to add to context")
    }
}