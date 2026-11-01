import Foundation
import Testing

@testable import MahjongMania

/// SPEC §19.5 and §19.6: what the App Store review looks at.
struct ComplianceTests {
  @Test func theInAppLinksPointAtThePublicPages() {
    #expect(AppLinks.privacy.absoluteString == "https://joshbelot.github.io/mahjong-mania/privacy.html")
    #expect(AppLinks.support.absoluteString == "https://joshbelot.github.io/mahjong-mania/support.html")
    for url in [AppLinks.site, AppLinks.privacy, AppLinks.support] {
      #expect(url.scheme == "https" && url.host == "joshbelot.github.io")
    }
  }

  @Test func thePrivacyManifestDeclaresNoTrackingAndNoCollectedData() throws {
    let url = try #require(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    let plist = try #require(
      PropertyListSerialization.propertyList(from: Data(contentsOf: url), format: nil) as? [String: Any])
    #expect(plist["NSPrivacyTracking"] as? Bool == false)
    #expect((plist["NSPrivacyTrackingDomains"] as? [Any])?.isEmpty == true)
    #expect((plist["NSPrivacyCollectedDataTypes"] as? [Any])?.isEmpty == true)
    // The app reads no required-reason API (it does not use UserDefaults, file timestamps or disk space).
    #expect((plist["NSPrivacyAccessedAPITypes"] as? [Any])?.isEmpty == true)
  }

  @Test func theAppDeclaresNoNetworkOrDataUsage() throws {
    let info = Bundle.main.infoDictionary ?? [:]
    #expect(info["ITSAppUsesNonExemptEncryption"] as? Bool == false)
    #expect(!info.keys.contains { $0.hasSuffix("UsageDescription") }, "no permission prompts")
  }
}
