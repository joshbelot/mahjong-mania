# Submission checklist (owner)

Everything an agent could prepare is in this folder. These steps are yours, in App Store Connect
(https://appstoreconnect.apple.com), in this order. Tick them off as you go.

## Before you start
- [ ] On a real iPhone, install build **1.3** from TestFlight and play through it once: a Practice lesson, Today's Deal, the Helper, a Game Night with four players, a card's QR code, and Settings, About (open Privacy Policy and Support). Haptics, sound and VoiceOver are the things only a real phone can check.
- [ ] Open `https://joshbelot.github.io/mahjong-mania/privacy.html` and `/support.html` in Safari and read them. You decide whether you are happy for the GitHub Issues link to be the only contact.

## The app record (My Apps, Mahjong Mania: Companion)
- [ ] **Pricing and Availability:** Price **Free**. Choose your countries.
- [ ] Untick **Make this app available on Mac (Apple silicon)** unless you have tested it on a Mac.
- [ ] **App Privacy:** answer as in `app-privacy.md` (Data Not Collected). Add the Privacy Policy URL.
- [ ] **Age Rating:** answer as in `age-rating.md` (4+).
- [ ] **EU Digital Services Act trader status:** your decision. A free hobby app with no revenue may be declared **non-trader**; a trader must publish contact details (App Store Connect shows them publicly in the EU). Pick the one that is true for you.
- [ ] **Content rights:** No third-party content.

## The 1.3 version page
- [ ] Open the version page (iOS App, 1.3 Prepare for Submission).
- [ ] Paste **Name**, **Subtitle**, **Promotional text**, **Description**, **Keywords**, **Support URL** and **Copyright** from `metadata.md`. Check the counters turn green.
- [ ] Choose the categories: primary **Games, Board**; secondary **Education**.
- [ ] Upload the screenshots from `screenshots/6.9/` to the 6.9-inch iPhone slot (App Store Connect can scale them down for the other sizes). If it asks for 6.5-inch screenshots too, upload `screenshots/6.5/`.
- [ ] Paste "What's New" from `metadata.md`.
- [ ] **Build:** click "+" and attach build **1.3** (the build number from TestFlight, shown in `docs/PROGRESS.md`).
- [ ] **App Review Information:** untick "Sign-in required". Paste `review-notes.md` into Notes. Add a phone number and email where Apple can reach you (these are not shown to the public).
- [ ] **Version Release:** choose manual or automatic release.

## Submit
- [ ] Click **Add for Review**, then **Submit to App Review**.
- [ ] Watch your email for questions from App Review. Typical review is a day or two.
