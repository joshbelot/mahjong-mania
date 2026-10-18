import AVFoundation
import SwiftUI

/// The Practice sound effects (SPEC §18.7), written by `tools/make_sounds.py`.
enum Sound: String, CaseIterable, Sendable {
  case right, wrong, combo, star1, star2, star3, fanfare, unlock
}

/// Plays the effects on an ambient audio session: the silent switch mutes them and other audio keeps playing.
/// No permission is needed.
@MainActor
final class SoundPlayer {
  static let shared = SoundPlayer()
  private var players: [Sound: AVAudioPlayer] = [:]
  private var configured = false

  private func configure() {
    guard !configured else { return }
    configured = true
    let session = AVAudioSession.sharedInstance()
    try? session.setCategory(.ambient, mode: .default, options: [.mixWithOthers])
    try? session.setActive(true)
  }

  func play(_ sound: Sound) {
    configure()
    if players[sound] == nil, let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") {
      players[sound] = try? AVAudioPlayer(contentsOf: url)
      players[sound]?.prepareToPlay()
    }
    guard let player = players[sound] else { return }
    player.currentTime = 0
    player.play()
  }

  /// Loads every sound so the first one is not late.
  func warmUp() {
    configure()
    for sound in Sound.allCases where players[sound] == nil {
      if let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav") {
        players[sound] = try? AVAudioPlayer(contentsOf: url)
        players[sound]?.prepareToPlay()
      }
    }
  }
}

private struct SoundsEnabledKey: EnvironmentKey {
  static let defaultValue = true
}

extension EnvironmentValues {
  /// Mirrors `settings.soundEffects`; set once at the app root.
  var soundsEnabled: Bool {
    get { self[SoundsEnabledKey.self] }
    set { self[SoundsEnabledKey.self] = newValue }
  }
}

private struct SoundOnChange<Trigger: Equatable>: ViewModifier {
  @Environment(\.soundsEnabled) private var enabled
  let sound: (Trigger) -> Sound?
  let trigger: Trigger

  func body(content: Content) -> some View {
    content.onChange(of: trigger) { _, new in
      guard enabled, let sound = sound(new) else { return }
      SoundPlayer.shared.play(sound)
    }
  }
}

extension View {
  /// Plays a sound when `trigger` changes (if Sound effects is on); return nil to stay quiet.
  func sound<Trigger: Equatable>(trigger: Trigger, _ sound: @escaping (Trigger) -> Sound?) -> some View {
    modifier(SoundOnChange(sound: sound, trigger: trigger))
  }
}
