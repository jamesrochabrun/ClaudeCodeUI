import SwiftUI

struct CodeSelectionsSectionView: View {
  let selections: [TextSelection]
  
  var body: some View {
    VStack(alignment: .leading, spacing: 8) {
      ForEach(selections) { selection in
        ActiveFileView(model: .selection(selection))
          .transition(.asymmetric(
            insertion: .scale(scale: 0.95).combined(with: .opacity),
            removal: .scale(scale: 0.95).combined(with: .opacity)
          ))
      }
    }
  }
}