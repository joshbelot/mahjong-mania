import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

private let fast: Duration = .milliseconds(10)

private func tiles(_ codes: String) -> [Tile] {
  LaunchOptions.tiles(fromCodes: codes)
}

/// A varied 13-tile Charleston hand with a joker.
private let sample = "1C,2C,3C,5D,5D,6D,6D,6D,N,R,0,F,J"

@MainActor
struct CharlestonLifeCycleTests {
  private let analyzer = Analyzer(card: PracticeCard.card)

  private func makeStore(rack: String = sample, east: Bool = false) -> HelperStore {
    let store = HelperStore(directory: makeTempDirectory(), persistDelay: fast)
    if east { store.setEast(true) }
    store.setRack(tiles(rack))
    return store
  }

  /// Takes the locked tiles out of the rack and puts `incoming` in; returns the locked tiles.
  @discardableResult
  private func swapAll(_ store: HelperStore, incoming: [String]) -> [Tile] {
    let locked = store.charleston.locked?.tiles ?? []
    for tile in locked {
      if let index = store.rack.firstIndex(of: tile) { store.removeTile(at: index) }
    }
    for code in incoming { store.add(Tile(code: code)!) }
    return locked
  }

  @Test func nothingLocksBeforeTheRackIsFull() {
    let store = makeStore(rack: "1C,2C,3C,5D,5D,6D,6D,6D,N,R,0,F")
    #expect(store.rack.count == 12)
    #expect(!store.canLockSuggestion)
    store.lockSuggestionIfNeeded(using: analyzer)
    #expect(store.charleston.locked == nil)
  }

  @Test func fullRackLocksThreeTilesAndNeverAJoker() throws {
    let store = makeStore()
    #expect(store.canLockSuggestion)
    store.lockSuggestionIfNeeded(using: analyzer)
    let locked = try #require(store.charleston.locked)
    #expect(locked.tiles.count == 3)
    #expect(locked.reasons.count == 3)
    #expect(!locked.tiles.contains(.joker))
    #expect(store.charleston.passIndex == 0)
    #expect(store.trackerText == "Pass 1 of 7 \u{00B7} Right")
  }

  @Test func theLockHoldsStillWhileTilesAreSwapped() throws {
    let store = makeStore()
    store.lockSuggestionIfNeeded(using: analyzer)
    let first = try #require(store.charleston.locked)
    // Take out two suggested tiles and one other tile, then add two: still short of full.
    store.removeTile(at: store.rack.firstIndex(of: first.tiles[0])!)
    store.removeTile(at: store.rack.firstIndex(of: first.tiles[1])!)
    store.add(.number(9, .bams))
    #expect(store.rack.count == 12)
    #expect(store.charleston.locked?.tiles == first.tiles)
    #expect(store.charleston.passIndex == 0)
    store.lockSuggestionIfNeeded(using: analyzer)
    #expect(store.charleston.locked?.tiles == first.tiles, "never recomputed while locked")
  }

  @Test func removingThreeAndAddingThreeStartsTheNextPass() throws {
    let store = makeStore()
    store.lockSuggestionIfNeeded(using: analyzer)
    let removed = swapAll(store, incoming: ["9B", "9B", "8B"])
    #expect(removed.count == 3)
    #expect(store.rack.count == 13)
    #expect(store.charleston.locked == nil)
    #expect(store.charleston.passIndex == 1)
    #expect(store.trackerText == "Pass 2 of 7 \u{00B7} Across")
    store.lockSuggestionIfNeeded(using: analyzer)
    let next = try #require(store.charleston.locked)
    #expect(next.removedSinceLock.isEmpty && next.addedSinceLock == 0)
  }

  @Test func oneSwapIsEnoughToUnlock() throws {
    let store = makeStore()
    store.lockSuggestionIfNeeded(using: analyzer)
    let locked = try #require(store.charleston.locked)
    store.removeTile(at: store.rack.firstIndex(of: locked.tiles[0])!)
    store.add(.number(9, .bams))
    #expect(store.charleston.locked == nil)
    #expect(store.charleston.passIndex == 1)
  }

  @Test func addingBeforeRemovingDoesNotUnlockUntilBothHappenAtFullSize() throws {
    // 12 tiles, locked by hand: add one (full), nothing removed since the lock -> stays locked.
    let store = makeStore(rack: "1C,2C,3C,5D,5D,6D,6D,6D,N,R,0,F")
    store.lockSuggestion(using: analyzer)
    store.add(.joker)
    #expect(store.rack.count == 13)
    #expect(store.charleston.locked != nil)
    #expect(store.charleston.passIndex == 0)
    // Now remove one and add it back: both happened and the rack is full again.
    store.removeTile(at: 0)
    #expect(store.charleston.locked != nil, "rack is not full yet")
    store.add(.number(1, .cracks))
    #expect(store.charleston.locked == nil)
    #expect(store.charleston.passIndex == 1)
  }

  @Test func passedRowsMatchByTile() {
    var locked = LockedPass(tiles: tiles("7B,7B,N"))
    #expect(locked.passed == [false, false, false])
    locked.removedSinceLock = tiles("7B")
    #expect(locked.passed == [true, false, false])
    locked.removedSinceLock = tiles("N,7B")
    #expect(locked.passed == [true, false, true])
    locked.removedSinceLock = tiles("7B,7B,2D")
    #expect(locked.passed == [true, true, false], "a tile that was not suggested ticks nothing")
  }

  @Test func eastNeedsFourteenTiles() {
    let store = makeStore(east: true)
    #expect(store.fullRackSize == 14)
    #expect(!store.canLockSuggestion, "13 tiles is not a full East hand")
    store.add(.number(9, .bams))
    #expect(store.canLockSuggestion)
    #expect(HelperRules.rackLimit(mode: .charleston, exposedTiles: 0, isEast: true) == 14)
    #expect(HelperRules.rackLimit(mode: .charleston, exposedTiles: 0, isEast: false) == 13)
    #expect(HelperRules.fullRackCount(mode: .charleston, exposedTiles: 0, isEast: true) == 14)
  }

  @Test func trackerFollowsTheSequence() {
    let store = makeStore()
    #expect(store.steps.map(\.direction) == ["Right", "Across", "Left", "Left", "Across", "Right", "Across"])
    store.sequence = CharlestonSequence(second: false, courtesy: true)
    #expect(store.steps.count == 4)
    #expect(store.trackerText == "Pass 1 of 4 \u{00B7} Right")
    store.sequence = CharlestonSequence(second: false, courtesy: false)
    #expect(store.steps.count == 3)
    #expect(!store.canStopAfterFirst, "nothing follows the first Charleston")
  }

  @Test func courtesyAndDone() throws {
    let driven = makeStore()
    for pass in 0..<6 {
      driven.lockSuggestionIfNeeded(using: analyzer)
      let locked = try #require(driven.charleston.locked, "pass \(pass)")
      for tile in locked.tiles { driven.removeTile(at: driven.rack.firstIndex(of: tile)!) }
      // Add back three tiles that are not at their copy limit.
      var added = 0
      for tile in Tile.allCases where added < 3 && driven.canAdd(tile) && !locked.tiles.contains(tile) {
        driven.add(tile)
        added += 1
      }
    }
    #expect(driven.charleston.passIndex == 6)
    #expect(driven.currentStep?.isCourtesy == true)
    #expect(driven.trackerText.contains("Courtesy"))
    #expect(driven.trackerText.contains("0\u{2013}3 tiles"))
    driven.lockSuggestionIfNeeded(using: analyzer)
    #expect(driven.charleston.locked?.tiles.count == 3, "the list still shows 3")
    let locked = try #require(driven.charleston.locked)
    for tile in locked.tiles { driven.removeTile(at: driven.rack.firstIndex(of: tile)!) }
    var added = 0
    for tile in Tile.allCases where added < 3 && driven.canAdd(tile) && !locked.tiles.contains(tile) {
      driven.add(tile)
      added += 1
    }
    #expect(driven.isCharlestonDone)
    #expect(driven.trackerText == "Charleston done")
    #expect(!driven.canLockSuggestion)
  }

  @Test func stopAfterFirstSkipsTheSecondCharleston() {
    let store = makeStore()
    #expect(store.canStopAfterFirst)
    store.stopAfterFirstCharleston()
    #expect(store.steps.map(\.direction) == ["Right", "Across", "Left", "Across"])
    #expect(!store.canStopAfterFirst)
    #expect(store.trackerText == "Pass 1 of 4 \u{00B7} Right")
  }

  @Test func startOverKeepsTheRackAndClearsTheLock() {
    let store = makeStore()
    store.lockSuggestionIfNeeded(using: analyzer)
    swapAll(store, incoming: ["9B", "9B", "8B"])
    #expect(store.charleston.passIndex == 1)
    let rack = store.rack
    store.restartCharleston()
    #expect(store.charleston == CharlestonState())
    #expect(store.rack == rack)
  }

  @Test func suggestAgainRecomputesAndRelocks() throws {
    let store = makeStore()
    store.lockSuggestionIfNeeded(using: analyzer)
    let first = try #require(store.charleston.locked)
    store.removeTile(at: store.rack.firstIndex(of: first.tiles[0])!)
    store.lockSuggestion(using: analyzer)
    let again = try #require(store.charleston.locked)
    #expect(again.removedSinceLock.isEmpty && again.addedSinceLock == 0)
    #expect(store.charleston.passIndex == 0)
  }

  @Test func theStateSurvivesARelaunch() throws {
    let directory = makeTempDirectory()
    let store = HelperStore(directory: directory, persistDelay: fast)
    store.setEast(true)
    store.setRack(tiles(sample + ",9B"))
    store.lockSuggestionIfNeeded(using: analyzer)
    store.removeTile(at: 0)
    store.flush()
    let reloaded = HelperStore(directory: directory, persistDelay: fast)
    #expect(reloaded.isEast)
    #expect(reloaded.charleston == store.charleston)
    #expect(reloaded.charleston.locked?.removedSinceLock.count == 1)
  }

  @Test func aV1HelperFileStillLoads() throws {
    let directory = makeTempDirectory()
    let json = #"{"version":1,"mode":"playing","rack":["1C","2C"],"exposures":[],"seen":{},"opponents":[],"pinnedLineID":null}"#
    try json.write(to: directory.appendingPathComponent("helper.json"), atomically: true, encoding: .utf8)
    let store = HelperStore(directory: directory, persistDelay: fast)
    #expect(store.mode == .playing)
    #expect(store.rack.count == 2)
    #expect(!store.isEast)
    #expect(store.charleston == CharlestonState())
  }
}
