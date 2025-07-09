import SwiftUI

struct AttachmentsSectionView: View {
  let attachments: [FileAttachment]
  
  var body: some View {
    ScrollView(.horizontal, showsIndicators: false) {
      HStack(spacing: 12) {
        ForEach(attachments) { attachment in
          AttachmentPreviewView(attachment: attachment, onRemove: {})
            .allowsHitTesting(false) // Disable interaction in message view
        }
      }
      .padding(.horizontal, 12)
    }
  }
}