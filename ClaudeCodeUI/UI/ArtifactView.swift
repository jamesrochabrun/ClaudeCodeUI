import SwiftUI

struct ArtifactView: View {
  
  let artifact: Artifact
  
  @Environment(\.dismiss) private var dismiss
  @Environment(\.colorScheme) private var colorScheme
  
  var body: some View {
    ZStack(alignment: .topTrailing) {
      content
      topBar
        .padding()
    }
  }
  
  @ViewBuilder
  private var content: some View {
    switch artifact {
    case .diagram(let diagramContent):
      MermaidView(diagram: diagramContent)
        .frame(width: 850, height: 800)
    }
  }
  
  private var topBar: some View {
    HStack(alignment: .center) {
      Spacer()
      Button(action: {
        dismiss()
      }) {
        Image(systemName: "xmark")
          .resizable()
          .scaledToFit()
          .font(Font.body.weight(.bold))
          .scaleEffect(0.65)
          .foregroundColor(.primary)
          .frame(width: 22, height: 22)
          .padding(8)
          .background(.ultraThinMaterial, in: Circle())
      }
      .buttonStyle(.plain)
    }
  }
}
