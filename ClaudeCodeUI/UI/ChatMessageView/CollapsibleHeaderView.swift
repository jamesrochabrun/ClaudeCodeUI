import SwiftUI

struct CollapsibleHeaderView: View {
  
  let messageType: MessageType
  let toolName: String?
  let toolInputData: ToolInputData?
  let isExpanded: Binding<Bool>
  let fontSize: Double
  
  var body: some View {
    HStack(spacing: 12) {
      // Checkmark indicator
      Image(systemName: isExpanded.wrappedValue ? "checkmark.circle.fill" : "checkmark.circle")
        .font(.system(size: 14))
        .foregroundStyle(statusColor)
        .frame(width: 20, height: 20)
      
      // Message type label
      Text(headerText)
        .font(.system(size: fontSize - 1, design: .monospaced))
        .foregroundStyle(.primary)
      
      Spacer()
      
      // Expand/collapse chevron
      Image(systemName: "chevron.right")
        .font(.system(size: 12, weight: .medium))
        .foregroundStyle(.secondary)
        .rotationEffect(.degrees(isExpanded.wrappedValue ? 90 : 0))
    }
    .padding(.horizontal, 8)
    .padding(.vertical, 4)
    .background(
      RoundedRectangle(cornerRadius: 5, style: .continuous)
        .fill(.ultraThinMaterial)
        .overlay(
          RoundedRectangle(cornerRadius: 5, style: .continuous)
            .strokeBorder(
              LinearGradient(
                colors: [
                  Color(red: 147/255, green: 51/255, blue: 234/255).opacity(0.3),
                  Color(red: 147/255, green: 51/255, blue: 234/255).opacity(0.1)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
              ),
              lineWidth: 1
            )
        )
    )
    .contentShape(Rectangle())
    .onTapGesture {
      withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
        isExpanded.wrappedValue.toggle()
      }
    }
  }
  
  private var headerText: String {
    switch messageType {
    case .toolUse:
      let name = toolName ?? "Tool Use"
      return toolInputData?.headerText(for: name) ?? name
    case .toolResult:
      return "Processing result"
    case .toolError:
      return "Error occurred"
    case .thinking:
      return "Thinking..."
    case .webSearch:
      return "Searching the web"
    default:
      return "Processing"
    }
  }
  
  private var statusColor: SwiftUI.Color {
    switch messageType {
    case .toolUse, .thinking, .webSearch:
      return .bookCloth
    case .toolResult:
      return .manilla
    case .toolError:
      return .red
    default:
      return .secondary
    }
  }
}