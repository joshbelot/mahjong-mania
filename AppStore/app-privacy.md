# App Privacy (the "nutrition label")

App Store Connect, App Privacy.

1. "Do you or your third-party partners collect data from this app?" **No**.
2. That is the only question. The label then reads **Data Not Collected**.
3. Privacy Policy URL: `https://joshbelot.github.io/mahjong-mania/privacy.html`

Why this is true (for your own check):

- The app makes no network requests (no URLSession, no web views, no SDKs).
- No analytics, advertising, crash reporting or tracking of any kind.
- `PrivacyInfo.xcprivacy` declares no tracking, no tracking domains, no collected data types and no required-reason APIs (the app reads none).
- Everything the user enters stays in the app's own storage on the device.

Also in App Store Connect:

- **Export compliance:** the app sets `ITSAppUsesNonExemptEncryption` to false (it uses no encryption beyond what the system provides), so no question should appear.
- **Content rights:** the app does not show third-party content. Answer "No".
