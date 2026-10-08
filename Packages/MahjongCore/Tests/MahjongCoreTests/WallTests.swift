import Testing

@testable import MahjongCore

struct WallTests {
  @Test func fullWallHasAllTilesWithRightCopies() {
    let wall = Wall.full()
    #expect(wall.count == 152)
    let counts = wall.counts
    #expect(counts.count == 36)
    for tile in Tile.allCases { #expect(counts[tile] == tile.copies) }
  }

  @Test func splitMix64MatchesReferenceVectors() {
    var zero = SeededRandom(seed: 0)
    #expect(zero.next() == 0xE220_A839_7B1D_CDAF)
    #expect(zero.next() == 0x6E78_9E6A_A1B9_65F4)
    #expect(zero.next() == 0x06C4_5D18_8009_454F)
    var other = SeededRandom(seed: 1_234_567)
    #expect(other.next() == 0x599E_D017_FB08_FC85)
    #expect(other.next() == 0x2C73_F084_5854_0FA5)
  }

  @Test func sameSeedGivesSameDeal() {
    let a = Wall.deal(seed: 42)
    let b = Wall.deal(seed: 42)
    #expect(a.hand == b.hand)
    #expect(a.rest == b.rest)
  }

  @Test func differentSeedsGiveDifferentDeals() {
    var hands: Set<[Tile]> = []
    for seed in 1...20 as ClosedRange<UInt64> { hands.insert(Wall.deal(seed: seed).hand) }
    #expect(hands.count == 20)
  }

  @Test func dealSplitsTheWholeWall() {
    let deal = Wall.deal(seed: 7, count: 14)
    #expect(deal.hand.count == 14)
    #expect(deal.rest.count == 152 - 14)
    #expect((deal.hand + deal.rest).counts == Wall.full().counts)
    #expect(Wall.deal(seed: 7).hand.count == 13)
  }

  @Test func dealCountIsClamped() {
    #expect(Wall.deal(seed: 1, count: -3).hand.isEmpty)
    #expect(Wall.deal(seed: 1, count: 500).rest.isEmpty)
  }

  @Test func shuffleIsAPermutation() {
    let items = Array(0..<50)
    let shuffled = SeededRandom.shuffled(items, seed: 99)
    #expect(shuffled.sorted() == items)
    #expect(shuffled != items)
  }
}
