import Foundation
import MahjongCore
import Testing

@testable import MahjongMania

private let fast: Duration = .milliseconds(10)

@MainActor
struct PendingCardSetupTests {
  @Test func oldSettingsFilesDecodeWithoutPendingSetup() throws {
    let json = #"{"version":1,"onboardingDone":true,"assistLevel":"coach"}"#
    let settings = try JSONDecoder().decode(AppSettings.self, from: Data(json.utf8))
    #expect(!settings.pendingCardSetup)
    #expect(settings.onboardingDone)
  }

  @Test func pendingSetupSurvivesRelaunch() {
    let directory = makeTempDirectory()
    let store = SettingsStore(directory: directory, persistDelay: fast)
    store.update { $0.pendingCardSetup = true; $0.onboardingDone = true }
    store.flush()
    let reloaded = SettingsStore(directory: directory, persistDelay: fast)
    #expect(reloaded.settings.pendingCardSetup)
    #expect(reloaded.settings.activeCardID == AppSettings.practiceCardID)
  }
}

struct GuidedEditorModelTests {
  private func line(_ text: String) -> CardLine {
    guard case .success(let parsed) = Notation.parseLine(text, id: "a", section: "Year") else {
      Issue.record("Did not parse \(text)")
      fatalError()
    }
    return parsed
  }

  private func card(_ text: String) -> Card {
    let result = Notation.parseCardFile(text)
    return Notation.makeCard(from: result, id: "c", fallbackName: "C", createdAt: Date(timeIntervalSince1970: 0))
  }

  @Test func newHandStartsEmptyAndCannotSave() {
    let model = GuidedEditorModel(availableSections: ["Year"])
    #expect(!model.canSave)
    #expect(model.line.tileCount(ofAlternative: 0) == 0)
  }

  @Test func buildingGroupsProducesTheSameLineAsTypingNotation() throws {
    var model = GuidedEditorModel(availableSections: ["Year"])
    model.line.alternatives = [[]]
    model.addGroup(to: 0)  // 11/x
    model.line.alternatives[0][0] = GroupSpec(tile: .fixed(.flower), count: 2)
    for (digit, ref, count) in [(2, SuitRef.variable(.x), 4), (4, .variable(.y), 4), (6, .variable(.z), 4)] {
      model.addGroup(to: 0)
      model.line.alternatives[0][model.line.alternatives[0].count - 1] = GroupSpec(tile: .number(digit, ref), count: count)
    }
    // Drop the default group added first, which was replaced; the list now has 4 groups = 14 tiles.
    let valid = try #require(model.validLine)
    let typed = line("FF 2222/x 4444/y 6666/z ; 25 ; X")
    #expect(GuidedLine.semanticSignature(valid) == GuidedLine.semanticSignature(typed))
  }

  @Test func addRemoveAndReorderGroups() {
    var model = GuidedEditorModel(availableSections: ["Year"])
    model.addGroup(to: 0)
    model.addGroup(to: 0)
    model.line.alternatives[0][1].tile = .fixed(.flower)
    model.moveGroup(1, by: -1, in: 0)
    #expect(model.line.alternatives[0][0].tile == .fixed(.flower))
    model.moveGroup(0, by: -1, in: 0)  // already first: no change
    #expect(model.line.alternatives[0][0].tile == .fixed(.flower))
    model.removeGroup(0, from: 0)
    #expect(model.line.alternatives[0].count == 1)
    model.addAlternative()
    #expect(model.line.alternatives.count == 2)
    model.removeAlternative(1)
    model.removeAlternative(0)  // the last remaining way is never removed
    #expect(model.line.alternatives.count == 1)
  }

  @Test func guidedAndAdvancedConvertWithoutChangingMeaning() throws {
    let existing = line("FF 2026/x 2222/y 6666/y ; 75 ; X ; Year hand")
    let cardValue = card("! C\n# Year\nFF 2026/x 2222/y 6666/y ; 75 ; X ; Year hand\n")
    let guided = try #require(GuidedEditorModel(card: cardValue, editing: cardValue.lines[0]))
    let advanced = guided.advanced
    #expect(advanced.points == 75 && advanced.name == "Year hand" && !advanced.concealed)
    let back = try #require(GuidedEditorModel(advanced: advanced))
    let valid = try #require(back.validLine)
    #expect(GuidedLine.semanticSignature(valid) == GuidedLine.semanticSignature(existing))
  }

  @Test func unsupportedSourceStaysAdvanced() {
    let cardValue = card("! C\n# Year\nFFFF 2222/x + 4444/y = 66/z ; 25 ; X\n")
    #expect(cardValue.lines.count == 1)
    #expect(GuidedEditorModel(card: cardValue, editing: cardValue.lines[0]) == nil)
    // And the advanced editor shows the source exactly as written.
    #expect(LineEditorModel(card: cardValue, editing: cardValue.lines[0]).notation == "FFFF 2222/x + 4444/y = 66/z")
  }

  @Test func invalidAdvancedNotationDoesNotConvert() {
    var advanced = LineEditorModel(availableSections: ["Year"])
    advanced.notation = "FF 22"
    #expect(GuidedEditorModel(advanced: advanced) == nil)
  }

  @Test func savingKeepsCommentsUnrelatedAndInvalidLines() throws {
    let source = "! C\n// my notes\n# Year\nthis is not a hand\nFF 2222/x 4444/y 66/z ; 25 ; X\n\n# Other\nNNNN EEE WWW SSS DD/x ; 30 ; X\n"
    var model = GuidedEditorModel(availableSections: ["Year", "Other"])
    model.base.sectionChoice = .existing("Year")
    model.line.alternatives = [[
      GroupSpec(tile: .fixed(.flower), count: 4), GroupSpec(tile: .number(1, .variable(.x)), count: 3),
      GroupSpec(tile: .number(2, .variable(.y)), count: 3), GroupSpec(tile: .number(3, .variable(.z)), count: 4)]]
    let saved = try #require(model.validLine)
    let text = CardEditing.text(adding: saved, to: source)
    #expect(text.contains("// my notes"))
    #expect(text.contains("this is not a hand"))
    #expect(text.contains("NNNN EEE WWW SSS DD/x ; 30 ; X"))
    #expect(text.contains(Notation.serialize(saved)))
  }

  @Test func quintsWithJokersAndEveryShiftAreSupported() throws {
    var model = GuidedEditorModel(availableSections: ["Year"])
    model.line.alternatives = [[
      GroupSpec(tile: .fixed(.flower), count: 5), GroupSpec(tile: .number(1, .variable(.x)), count: 5),
      GroupSpec(tile: .number(2, .variable(.y)), count: 4)]]
    for shift in [Shift.none, .consecutive, .parity] {
      model.line.shift = shift
      #expect(model.canSave, "shift \(shift)")
    }
  }
}
