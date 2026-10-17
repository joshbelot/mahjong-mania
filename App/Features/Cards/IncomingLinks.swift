import Foundation
import Observation

/// Links that opened the app (a scanned card QR code) and are waiting for the main screen to handle
/// them, which may be after onboarding.
@MainActor
@Observable
final class IncomingLinks {
  var pending: URL?

  func receive(_ url: URL) {
    pending = url
  }
}
