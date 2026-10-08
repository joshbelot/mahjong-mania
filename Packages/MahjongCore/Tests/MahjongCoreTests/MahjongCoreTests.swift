import Testing

@testable import MahjongCore

@Test func packageVersionIsExposed() {
  #expect(MahjongCore.version == "1.0")
}
