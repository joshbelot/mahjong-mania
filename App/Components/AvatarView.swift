import SwiftUI

/// A player's initials on their palette colour.
struct AvatarView: View {
  let name: String
  let colorIndex: Int
  var size: CGFloat = 40

  /// First letters of the first two words, uppercased; "?" for an empty name.
  static func initials(for name: String) -> String {
    let words = name.split(whereSeparator: { $0.isWhitespace })
    let letters = words.prefix(2).compactMap { $0.first }
    if letters.isEmpty { return "?" }
    return String(letters).uppercased()
  }

  var body: some View {
    Text(Self.initials(for: name))
      .font(.system(size: size * 0.4, weight: .bold, design: .rounded))
      .foregroundStyle(Color.white)
      .frame(width: size, height: size)
      .background(PlayerPalette.color(at: colorIndex), in: Circle())
      .accessibilityElement(children: .ignore)
      .accessibilityLabel(name)
  }
}

private struct AvatarPreview: View {
  @Environment(\.theme) private var theme

  var body: some View {
    HStack {
      ForEach(0..<8, id: \.self) { index in
        AvatarView(name: ["Alex Kim", "Bea", "Cy Lo", "Dana", "Eli", "Fay", "Gus", "Hana"][index], colorIndex: index, size: 36)
      }
    }
    .padding(Spacing.lg)
    .background(theme.bg)
  }
}

#Preview("Light") {
  AvatarPreview().preferredColorScheme(.light)
}

#Preview("Dark") {
  AvatarPreview().preferredColorScheme(.dark)
}
