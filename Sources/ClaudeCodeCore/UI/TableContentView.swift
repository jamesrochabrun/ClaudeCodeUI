import SwiftUI
import AppKit

struct TableContentView: View {
  
  @Bindable var table: TableElement
  let role: MessageRole
  
  @Environment(\.colorScheme) private var colorScheme
  @State private var hoveredRow: Int? = nil
  @State private var selectedFormat: CopyFormat = .tsv
  
  enum CopyFormat: String, CaseIterable {
    case tsv = "TSV"
    case csv = "CSV"
    case markdown = "Markdown"
    
    var icon: String {
      switch self {
      case .tsv: return "tablecells"
      case .csv: return "doc.text"
      case .markdown: return "m.square"
      }
    }
  }
  
  var body: some View {
    VStack(spacing: 0) {
      // Header
      HStack {
        Image(systemName: "tablecells")
          .font(.system(size: 12))
          .foregroundStyle(.secondary)
        
        Text("Table")
          .font(.system(size: 12, design: .monospaced))
          .foregroundStyle(.secondary)
        
        if !table.isComplete {
          ProgressView()
            .controlSize(.small)
            .frame(width: 15, height: 15)
        }
        
        Spacer()
        
        // Copy format selector
        Menu {
          ForEach(CopyFormat.allCases, id: \.self) { format in
            Button(action: {
              selectedFormat = format
              copyTable(format: format)
            }) {
              Label(format.rawValue, systemImage: format.icon)
            }
          }
        } label: {
          HStack(spacing: 4) {
            Image(systemName: "doc.on.doc")
              .font(.system(size: 12))
            Image(systemName: "chevron.down")
              .font(.system(size: 10))
          }
        }
        .buttonStyle(.plain)
        .help("Copy table")
      }
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .background(headerBackground)
      
      Divider()
      
      // Table content
      ScrollView([.horizontal, .vertical]) {
        VStack(spacing: 0) {
          // Headers
          if !table.headers.isEmpty {
            HStack(spacing: 0) {
              ForEach(Array(table.headers.enumerated()), id: \.offset) { index, header in
                TableCell(
                  content: header,
                  alignment: index < table.alignments.count ? table.alignments[index] : .left,
                  isHeader: true,
                  isFirstColumn: index == 0,
                  isLastColumn: index == table.headers.count - 1
                )
              }
            }
            .background(headerRowBackground)
            
            Divider()
              .background(borderColor)
          }
          
          // Data rows
          ForEach(Array(table.rows.enumerated()), id: \.offset) { rowIndex, row in
            HStack(spacing: 0) {
              ForEach(Array(row.enumerated()), id: \.offset) { colIndex, cell in
                TableCell(
                  content: cell,
                  alignment: colIndex < table.alignments.count ? table.alignments[colIndex] : .left,
                  isHeader: false,
                  isFirstColumn: colIndex == 0,
                  isLastColumn: colIndex == row.count - 1
                )
              }
            }
            .background(
              rowBackground(for: rowIndex)
                .opacity(hoveredRow == rowIndex ? 1.0 : 0.7)
            )
            .onHover { isHovered in
              hoveredRow = isHovered ? rowIndex : nil
            }
            
            if rowIndex < table.rows.count - 1 {
              Divider()
                .background(borderColor.opacity(0.3))
            }
          }
        }
      }
      .frame(minHeight: 100, maxHeight: 500)
      .background(tableBackground)
    }
    .clipShape(RoundedRectangle(cornerRadius: 6))
    .overlay(
      RoundedRectangle(cornerRadius: 6)
        .strokeBorder(borderColor, lineWidth: 1)
    )
  }
  
  private func copyTable(format: CopyFormat) {
    let content: String
    switch format {
    case .tsv:
      content = table.copyableContent
    case .csv:
      content = table.csvContent
    case .markdown:
      content = generateMarkdown()
    }
    
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(content, forType: .string)
  }
  
  private func generateMarkdown() -> String {
    var result = "| " + table.headers.joined(separator: " | ") + " |\n"
    result += "|"
    for alignment in table.alignments {
      switch alignment {
      case .left:
        result += " :--- |"
      case .center:
        result += " :---: |"
      case .right:
        result += " ---: |"
      }
    }
    result += "\n"
    
    for row in table.rows {
      result += "| " + row.joined(separator: " | ") + " |\n"
    }
    
    return result.trimmingCharacters(in: .whitespacesAndNewlines)
  }
  
  private var headerBackground: Color {
    colorScheme == .dark
    ? Color(white: 0.15)
    : Color(white: 0.95)
  }
  
  private var tableBackground: Color {
    colorScheme == .dark
    ? Color(white: 0.08)
    : Color.white
  }
  
  private var headerRowBackground: Color {
    colorScheme == .dark
    ? Color(white: 0.12)
    : Color(white: 0.97)
  }
  
  private func rowBackground(for index: Int) -> Color {
    if index % 2 == 0 {
      return colorScheme == .dark
      ? Color(white: 0.1)
      : Color(white: 0.99)
    } else {
      return colorScheme == .dark
      ? Color(white: 0.06)
      : Color(white: 0.96)
    }
  }
  
  private var borderColor: Color {
    colorScheme == .dark
    ? Color(white: 0.25)
    : Color(white: 0.85)
  }
}

struct TableCell: View {
  let content: String
  let alignment: TableElement.TableAlignment
  let isHeader: Bool
  let isFirstColumn: Bool
  let isLastColumn: Bool
  
  @Environment(\.colorScheme) private var colorScheme
  
  var body: some View {
    Text(content)
      .font(.system(size: isHeader ? 13 : 12, weight: isHeader ? .semibold : .regular, design: .default))
      .foregroundColor(textColor)
      .lineLimit(nil)
      .multilineTextAlignment(textAlignment)
      .frame(maxWidth: .infinity, alignment: frameAlignment)
      .padding(.horizontal, 12)
      .padding(.vertical, 8)
      .overlay(alignment: .trailing) {
        if !isLastColumn {
          Rectangle()
            .fill(borderColor.opacity(0.3))
            .frame(width: 1)
        }
      }
      .textSelection(.enabled)
  }
  
  private var textColor: Color {
    if isHeader {
      return colorScheme == .dark
      ? Color.white.opacity(0.95)
      : Color.black.opacity(0.9)
    } else {
      return colorScheme == .dark
      ? Color.white.opacity(0.85)
      : Color.black.opacity(0.8)
    }
  }
  
  private var borderColor: Color {
    colorScheme == .dark
    ? Color(white: 0.25)
    : Color(white: 0.85)
  }
  
  private var textAlignment: TextAlignment {
    switch alignment {
    case .left: return .leading
    case .center: return .center
    case .right: return .trailing
    }
  }
  
  private var frameAlignment: Alignment {
    switch alignment {
    case .left: return .leading
    case .center: return .center
    case .right: return .trailing
    }
  }
}
