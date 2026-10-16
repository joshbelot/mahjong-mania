import Foundation
import MahjongCore
import SwiftUI
import Testing

@testable import MahjongMania

@MainActor
struct TileStyleTests {
  @Test func fourStylesWithPlainNames() {
    #expect(TileStyle.allCases.map(\.title) == ["Classic", "Traditional", "Large print", "Modern"])
    #expect(TileStyle.allCases.allSatisfy { $0.summary.count > 20 })
  }

  @Test func classicIsTheDefaultAndOldSettingsFilesStillLoad() throws {
    #expect(AppSettings().tileStyle == .classic)
    let directory = makeTempDirectory()
    try #"{"version":1,"assistLevel":"coach"}"#.write(
      to: directory.appendingPathComponent("settings.json"), atomically: true, encoding: .utf8)
    let store = SettingsStore(directory: directory, persistDelay: .milliseconds(10))
    #expect(store.settings.tileStyle == .classic)
    #expect(store.settings.assistLevel == .coach)
  }

  @Test func theChoiceIsSavedAndReloaded() {
    let directory = makeTempDirectory()
    let store = SettingsStore(directory: directory, persistDelay: .milliseconds(10))
    store.update { $0.tileStyle = .largePrint }
    store.flush()
    let reloaded = SettingsStore(directory: directory, persistDelay: .milliseconds(10))
    #expect(reloaded.settings.tileStyle == .largePrint)
  }

  @Test func onlyModernChangesTheFaceColour() {
    let theme = Theme.standard
    for style in [TileStyle.classic, .traditional, .largePrint] {
      for tile in Tile.allWithBlank {
        #expect(style.faceColor(for: tile, theme: theme) == theme.tileFace)
      }
    }
    #expect(TileStyle.modern.faceColor(for: .number(3, .dots), theme: theme) == theme.suitD)
    #expect(TileStyle.modern.faceColor(for: .number(3, .bams), theme: theme) == theme.suitB)
    #expect(TileStyle.modern.faceColor(for: .number(3, .cracks), theme: theme) == theme.suitC)
    #expect(TileStyle.modern.faceColor(for: .wind(.east), theme: theme) == theme.modernNeutral)
    #expect(TileStyle.modern.faceColor(for: .blank, theme: theme) == theme.tileFace)
  }

  @Test func pipLayoutsHaveTheRightCountAndStayOnTheTile() {
    for count in 1...9 {
      let points = PipLayout.points(for: count)
      #expect(points.count == count, "\(count) pips")
      #expect(points.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
      #expect(Set(points.map { "\($0.x),\($0.y)" }).count == count, "pips must not overlap exactly")
    }
  }
}
