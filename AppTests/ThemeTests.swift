import Testing

@testable import MahjongMania

struct ThemeTests {
  @Test func playerPaletteWrapsIndices() {
    #expect(PlayerPalette.hexes.count == 8)
    _ = PlayerPalette.color(at: -1)
    _ = PlayerPalette.color(at: 9)
  }

  @Test func standardThemeBuilds() {
    _ = Theme.standard
  }
}
