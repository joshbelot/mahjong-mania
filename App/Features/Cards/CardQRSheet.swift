import MahjongCore
import SwiftUI
import UniformTypeIdentifiers

/// The QR code picture as a shareable PNG named after the card ("Club Card.png").
struct QRImageExport: Transferable {
  let name: String
  let image: UIImage

  static func fileName(for cardName: String) -> String {
    CardFileExport.fileName(for: cardName).replacingOccurrences(of: ".txt", with: ".png")
  }

  static var transferRepresentation: some TransferRepresentation {
    FileRepresentation(exportedContentType: .png) { item in
      let url = FileManager.default.temporaryDirectory.appendingPathComponent(fileName(for: item.name))
      try item.image.pngData()?.write(to: url, options: .atomic)
      return SentTransferredFile(url)
    }
  }
}

/// Shows a user card as a QR code that the iPhone Camera can scan to add the card (SPEC §17.7).
struct CardQRSheet: View {
  @Environment(\.theme) private var theme
  @Environment(\.dismiss) private var dismiss
  @Environment(CardsStore.self) private var cards

  let card: Card

  private var plan: CardQRCode.Plan {
    CardQRCode.plan(fullText: cards.record(id: card.id)?.text, card: card)
  }

  var body: some View {
    NavigationStack {
      ScreenContainer {
        VStack(spacing: Spacing.lg) {
          Text(card.name)
            .font(Typography.h2)
            .foregroundStyle(theme.text)
            .multilineTextAlignment(.center)
            .accessibilityAddTraits(.isHeader)
            .accessibilityIdentifier("qr.name")
          if let url = plan.url, let image = CardQRCode.image(for: url) {
            Image(uiImage: image)
              .interpolation(.none)
              .resizable()
              .scaledToFit()
              .frame(maxWidth: 320)
              .padding(Spacing.sm)
              .background(Color.white, in: RoundedRectangle(cornerRadius: Radius.md))
              .accessibilityLabel("QR code for \(card.name)")
              .accessibilityIdentifier("qr.image")
            Text("Scan with your iPhone Camera to add this card")
              .font(Typography.body)
              .foregroundStyle(theme.text)
              .multilineTextAlignment(.center)
              .accessibilityIdentifier("qr.instruction")
            if plan.droppedComments {
              Text("Notes and comments in the card file aren't included, to keep the code small.")
                .font(Typography.small)
                .foregroundStyle(theme.textMuted)
                .multilineTextAlignment(.center)
            }
            ShareLink(
              item: QRImageExport(name: card.name, image: image),
              preview: SharePreview(QRImageExport.fileName(for: card.name), image: Image(uiImage: image))
            ) {
              Label("Share image", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButton(.primary, size: .large))
            .accessibilityIdentifier("qr.share")
          } else {
            Text("This card is too big for a QR code. Share it as a file instead.")
              .font(Typography.body)
              .foregroundStyle(theme.text)
              .multilineTextAlignment(.center)
              .accessibilityIdentifier("qr.tooBig")
            ShareLink(
              item: CardFileExport(card: card), subject: Text(card.name), preview: SharePreview(card.name)
            ) {
              Label("Share card as a file", systemImage: "square.and.arrow.up")
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(PrimaryButton(.primary, size: .large))
            .accessibilityIdentifier("qr.shareFile")
          }
        }
        .frame(maxWidth: .infinity)
      }
      .navigationTitle("QR code")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("Done") { dismiss() }
            .accessibilityIdentifier("qr.done")
        }
      }
    }
    .presentationDetents([.large])
    .presentationDragIndicator(.visible)
  }
}
