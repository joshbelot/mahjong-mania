import Foundation
import Testing

@testable import MahjongCore

struct TileTests {
  @Test func allCasesHasThirtySixTilesInSpecOrder() {
    let codes = Tile.allCases.map(\.code)
    #expect(codes.count == 36)
    let expected =
      (1...9).map { "\($0)C" } + (1...9).map { "\($0)B" } + (1...9).map { "\($0)D" }
      + ["N", "E", "W", "S", "R", "G", "0", "F", "J"]
    #expect(codes == expected)
  }

  @Test(arguments: Tile.allCases)
  func codeRoundTrips(tile: Tile) {
    #expect(Tile(code: tile.code) == tile)
  }

  @Test(arguments: ["0C", "10D", "X", "", "5", "5X", "1c", "n", "0D0", "9", "ＡB", "٣C"])
  func junkCodesAreRejected(code: String) {
    #expect(Tile(code: code) == nil)
  }

  @Test func copiesPerTile() {
    for tile in Tile.allCases {
      switch tile {
      case .flower, .joker: #expect(tile.copies == 8)
      default: #expect(tile.copies == 4)
      }
    }
  }

  @Test func matchingDragons() {
    #expect(Tile.matchingDragon(.cracks) == .dragon(.red))
    #expect(Tile.matchingDragon(.bams) == .dragon(.green))
    #expect(Tile.matchingDragon(.dots) == .dragon(.white))
  }

  @Test func namesAreHumanFriendly() {
    #expect(Tile.number(5, .dots).name == "5 Dot")
    #expect(Tile.number(1, .bams).name == "1 Bam")
    #expect(Tile.number(9, .cracks).name == "9 Crack")
    #expect(Tile.wind(.north).name == "North")
    #expect(Tile.wind(.east).name == "East")
    #expect(Tile.wind(.west).name == "West")
    #expect(Tile.wind(.south).name == "South")
    #expect(Tile.dragon(.red).name == "Red Dragon")
    #expect(Tile.dragon(.green).name == "Green Dragon")
    #expect(Tile.dragon(.white).name == "Soap (White Dragon)")
    #expect(Tile.flower.name == "Flower")
    #expect(Tile.joker.name == "Joker")
    #expect(Set(Tile.allCases.map(\.name)).count == 36)
  }

  @Test func comparableFollowsAllCasesOrder() {
    #expect(Tile.number(9, .cracks) < Tile.number(1, .bams))
    #expect(Tile.number(9, .dots) < Tile.wind(.north))
    #expect(Tile.dragon(.white) < Tile.flower)
    #expect(Tile.flower < Tile.joker)
    #expect(Tile.allCases.sorted() == Tile.allCases)
    for (index, tile) in Tile.allCases.enumerated() { #expect(tile.sortIndex == index) }
  }

  @Test func codableEncodesAsCodeString() throws {
    let data = try JSONEncoder().encode([Tile.number(5, .dots), .dragon(.white), .joker])
    #expect(String(decoding: data, as: UTF8.self) == "[\"5D\",\"0\",\"J\"]")
    let back = try JSONDecoder().decode([Tile].self, from: data)
    #expect(back == [.number(5, .dots), .dragon(.white), .joker])
  }

  @Test func decodingJunkThrows() {
    let data = Data("[\"ZZ\"]".utf8)
    #expect(throws: DecodingError.self) { try JSONDecoder().decode([Tile].self, from: data) }
  }

  @Test func countsAndDisplaySort() {
    let tiles: [Tile] = [.joker, .number(2, .bams), .number(2, .bams), .number(1, .cracks)]
    #expect(tiles.counts == [.joker: 1, .number(2, .bams): 2, .number(1, .cracks): 1])
    #expect(tiles.sortedForDisplay() == [.number(1, .cracks), .number(2, .bams), .number(2, .bams), .joker])
  }
}
