# Approved next waves: beginner clarity (1.4) and local card scanning (conditional 1.5)

**Status: ready for 1.4 execution; release prerequisite verified 2026-11-01.** Version **1.3 build 5** is uploaded and recorded as `VALID` in App Store Connect. Phases 31–33 merged in PRs #47–49; the completed release record merged in [PR #50](https://github.com/joshbelot/mahjong-mania/pull/50). The approved next scope is **1.4, phases 34–38**. The copy-pastable execution prompt is [TERRA_HANDOFF_1_4.md](TERRA_HANDOFF_1_4.md). Physical-device checks and App Store submission remain the owner's steps.

**1.5, phases 39–42, is a separately gated scanning wave.** Its local-only experiment is specified here so it does not need redesigning after 1.4. Production scanning requires the Phase 39 accuracy gate; it is not part of the 1.4 execution prompt. Owner-supplied card pictures are pending and do not block 1.4. No API spending, backend, advertising, subscription or scan-credit work is authorized by this document.

This is the authoritative supplement for these waves. Existing `docs/SPEC.md` still owns the app's engine, scoring, persistence and prior releases. In Phase 34, add a concise §20 pointer and phase checklist to SPEC, plus a 1.4 progress table in PROGRESS, referencing this document rather than duplicating requirements. Preserve 1.3 history and its real completion evidence. If another completed wave has already consumed these version/phase identifiers, reconcile and document the mapping before implementation; never overwrite another wave. AGENTS governs local gates and overrides obsolete CI references in the older SPEC. No CI is available or to be enabled.

## 0. Evidence and limits of this evaluation

**Verified execution baseline, 2026-11-01:** remote main is `2cf27b082e27a71cf80f15d08ad37df239378a7d`; the build-number bump is `0be416c`. The clean release checkout `/private/tmp/terra-release-main` contains main and the completed release records. The original workspace is still on `claude/release-1-3` at `5fb527b`, with these next-wave planning files untracked. Recheck worktree/branch state and preserve the planning files when creating the Phase 34 branch from current main. Do not base new implementation on that stale release branch. The evaluation below describes the older inspected baseline, not a fresh walkthrough of the completed 1.3 build.

Baseline inspected: main `d21dbcf`, plus the pending Phase 31/32 work described in `TERRA_HANDOFF_1_3.md`. Evidence includes the actual onboarding, practice, Helper, card-import/editor and scorekeeping source, Phase 29 lesson screenshot sequences, and Phase 32 store screenshots. Findings below distinguish observed copy/behavior from usability hypotheses.

**Fresh simulator evidence is available; the full screenshot-reviewed beginner walkthrough remains outstanding.** Simulator could not initially be selected through the desktop-control interface. On the owner's follow-up, a dedicated iPhone 17 Pro simulator named **Mahjong Beginner Audit**, UUID `9DA1BF04-F904-4A96-8EB7-319538866252`, was created and booted through Xcode's CLI. An isolated snapshot of `d21dbcf` is in `/private/tmp/mahjong-beginner-audit.96kLzv`. Four existing UI flows ran successfully on iOS 26.5 with zero failures or skips: onboarding choices/relaunch, first-lesson teaching/mistake/hint/completion, Helper empty state/example deal, and Practice Card duplication/edit/save. Fifteen screenshot attachments were exported; key onboarding, intro, wrong-answer and Helper captures were inspected. One runtime warning, “Invalid frame dimension (negative or non-finite),” was recorded; this baseline run is not warning clean and the finding is already in the 1.3 handoff. The result bundle is `Beginner.xcresult`, screenshots and manifest are in `screenshots/`, and the log is `walkthrough.log` under that audit directory. This is an automated simulator walkthrough, not a manually driven novice session: the Practice test uses answer-revealing accessibility flags. No existing simulator was reset or commandeered. Some older Phase 30 captures predate the latest UI changes; their Check buttons are not treated as current defects.

Before executing this wave, finish the first-time-player script in §7 on the integrated 1.3 build, on an isolated simulator. Attach fresh screenshots and amend findings that no longer apply. A designer/agent adopting a beginner perspective is an expert walkthrough, not evidence from an actual novice participant; keep those findings separate.

The fresh audit's `xcresulttool get build-results` reports zero compiler/analyzer warnings and zero errors. Its test-results summary separately records the one runtime layout warning above; these are different diagnostics and must not be conflated. The dedicated simulator is retained for later audit work and shut down when idle.

## 1. Release boundaries

**Clarity wave:** teach before asking; explain the exact tiles shown; make first actions and card setup understandable; provide a guided hand editor. Reuse the current game engine and progress systems. This wave can ship independently of scanning.

**Scanning wave:** private assisted import from a camera, Photos, or an image/PDF in Files, running on the device. Prototype and evaluate recognition first. It must never be a condition for shipping the clarity fixes or the current 1.3 release. Cloud inference is excluded from both waves.

**Operating-cost constraint:** this feature must not create a variable server/inference bill as adoption grows. The app remains free to download. Do not add advertising, scan-credit purchases, subscriptions, or a backend to fund recognition in this wave. Existing Apple developer/distribution expenses are separate from the requirement of no per-use inference charges. A spending cap limits a subsidy; it does not make the feature self-funding. If local recognition is imperfect, improve the review/correction flow or narrow supported inputs instead of adding a paid fallback. Optional voluntary support can be considered separately, but unproven donations or future revenue must not be assumed to cover operating costs.

No new playable full mahjong game, accounts, cloud storage, public card catalogue, paid inference dependency, or change to core scoring is included. Preserve iOS 17 compatibility and Foundation-only MahjongCore. Existing advanced notation and QR import remain available.

## 2. Beginner findings and resulting requirements

Priorities here describe product impact, not observed crash severity. P1 means fix before calling the teaching experience ready; P2 means improve in the clarity wave; P3 is a hypothesis to evaluate before implementation.

| ID | First-time-player question | Evidence | Requirement | Priority |
|---|---|---|---|---|
| B01 | What am I trying to make with these tiles? | Unit 1 starts with suit/dragon facts; the 14-tile matching goal is explained in Learn → Rules instead of the initial lesson. | A short first lesson orientation defines a winning hand, a rack, and a card line with an illustrated original example. Keep the Practice start prominent. | P2 |
| B02 | How was I supposed to know there are four copies? | `TileFacts.suitsAndDragons` includes suited/wind/dragon copy counts. The Unit 1 Lesson 1 intro teaches suit names and dragon matches, but no copy counts. The saved wrong-answer sequence asks about four copies immediately. | Teach every fact before it can be scored, including copy counts, dealing, and the first Charleston direction. Audit all generated pools, not just one seed. | P1 |
| B03 | Is a set the whole box or a group of tiles? | A count question says “How many 7 Bams are in a set?”; joker questions call a pung a set. | Say “full tile set” for the collection and “group” for a hand component. Use the traditional names after defining them. | P1 |
| B04 | Do eight Flowers count as one tile in my hand? | The Unit 1 Lesson 2 intro says “Eight Flowers all count as one tile.” | Explicitly distinguish quantity from interchangeability: eight separate Flowers; any Flower can fill a Flower position. | P1 |
| B05 | Why does it say 1s when I am looking at 7s? | The saved Like Sandwich question displays 7s; feedback uses `Notation.describe` on the printed variant. `matchesLine` and `whichHand` both take this path. | Describe the concrete target and suit binding shown. Explain why a shifted number is legal, with the correct group counts. | P1 |
| B06 | Does red always mean Cracks? What are A, B and C? | The tile lesson associates physical tile artwork with fixed suit colors; Unit 2 switches to arbitrary pattern colors. Feedback uses “suit A/B/C.” | Teach the distinction with one concrete worked example. Provide a legend for the current example; regular feedback uses actual suit names. Add a non-color indication for suit relationships. | P1 |
| B07 | What does this grid or lightbulb do? Will help lower my score? | Header Tiles/Hint controls are icons. Hint cost is described in an accessibility hint; opening Tiles does not have the same scoring effect. | Use visible labels and explain the different effects before a first hint is consumed. Keep instructional review and cheat sheet behavior distinct from hints. | P2 |
| B08 | What should I do first: the daily puzzle, a test, or a lesson? | Today's Deal and Test out coexist with the first lesson; the goal ring shows a fraction and XP/streak controls have little visible explanation. | Prominent “Start here” on the next lesson; “Daily puzzle” explanation; “Skip ahead” explanation for Test out; readable daily goal label. No extra modal tour. | P2 |
| B09 | I chose my own card. Why am I using the Practice Card? | All onboarding card choices set Practice Card active; choosing own card only promises later manual navigation to Cards → New. | Remember setup intent and provide a direct setup action after onboarding, with an explicit Practice Card fallback. Never activate an empty card accidentally. | P2 |
| B10 | Do I have to learn a text language to add a hand? | `LineEditorView` begins with a notation field; Import begins with card-file text and a QR-picture option. | Add guided group entry and an import-method chooser. Advanced text entry remains one tap away. | P2 |
| B11 | What do Charleston, Scout, “8 away,” and “dead” mean here? | Helper exposes modes and engine result language before a novice has learned these terms. | One concise mode description, a concrete distance explanation, a dead-hand reason, and context help linked to the right Learn section. | P2 |
| B12 | Do I need to configure every house rule just to score? What is a wall game? | Session setup exposes rules/money, and the scoreboard has Wall game as a main action. | Keep Standard rules as the easy start; explain optional settings and “Wall game — no winner” without changing scoring defaults. | P2 |
| B13 | Why do several reward screens interrupt me after my first lesson? | PROGRESS documents completion followed by level/badge/goal celebrations. | Observe and report only in this wave. A reward-flow redesign needs separate scope; fix an actual navigation/accessibility defect only if reproduced, with a regression test. | P3 |
| B14 | Where are “Your exposed sets”? Why is this tip here before I play? | Fresh `helper-empty-light` and `helper-charleston-dealt-light` screenshots show “Called a discard? Add the set under Your exposed sets” while Charleston is selected; that control belongs to Playing mode. | Filter coach tips by current mode and visible task. A tip must not direct a beginner to a control absent from the current mode. | P2 |
| B15 | I entered all my tiles; where is the advice? | Fresh full-rack Charleston capture shows the rack and a large pass-control card; the Pass these advice starts below the visible viewport even after the keyboard collapses. | Keep the current pass as a compact summary with expandable details, so a full-rack user can discover the next useful action without a large control panel dominating the screen. Confirm layout at the smallest phone before choosing exact spacing. | P2 |

## 3. Clarity wave: required behavior and copy

### 3.1 Teach before scored questions

Introduce these short teaching blocks in the existing lesson intro design. Use a few labelled examples and short paragraphs; keep longer reference material behind “Read more.” Do not put the correct answer beside a scored question.

**First Practice orientation:**

> Your goal is to make a hand of 14 tiles that matches one line on a card. A line is a recipe for the tiles you need. Start by learning the tiles; then practise reading those recipes.

> Your rack holds your tiles. In a real game, you play with tiles at the table; these lessons give you short puzzles to practise.

**Unit 1: Suits and dragons**, split into readable blocks within the existing intro rather than one dense paragraph:

> There are three numbered suits: Cracks (Characters), Bams (Bamboo), and Dots (Circles). Each suit has tiles numbered 1 to 9.

> The full tile set has four copies of each numbered tile, four of each Wind, and four of each Dragon.

> Some card patterns ask for a suit's matching Dragon: Red with Cracks, Green with Bams, and White — also called Soap — with Dots.

**Unit 1: Flowers, jokers and Soap:**

> A standard American mahjong set has 152 tiles, including eight Flowers and eight Jokers.

> All Flowers are interchangeable. Each Flower is still one tile: a pair of Flowers needs two Flower tiles.

> A Joker can replace a tile in a group of three or more matching tiles. It cannot replace a tile in a single or pair. You cannot pass a Joker during the Charleston.

> Soap is the White Dragon. In year patterns, it also represents the digit 0.

**Before dealing questions enter the pool:**

> East is the dealer. East starts with 14 tiles; everyone else starts with 13. The Charleston is a round of tile swapping before play: first right, then across, then left. The full procedure is in Learn.

Audit all facts in all three Unit 1 lessons and later exercise prerequisites. For each generated fact, record a stable concept identifier and the intro/previous lesson that teaches it. Add deterministic coverage ensuring a scored lesson's possible concepts are covered by its own or prior teaching, with human review of the actual copy. Metadata coverage does not prove the teaching is understandable.

A user can reopen “Lesson notes” from an ordinary lesson without leaving the question, losing selections, consuming a hint, or earning/losing XP. It presents already-taught content only. Do not offer it in gold lessons, checkpoints, test-out, custom/free-play sessions, Daily Deal, or Speed Round. Keep existing assessment rules intact; do not enable hints where they are currently prohibited. Existing assessment-specific Tiles restrictions remain intact. First-time intros still appear before questions; replaying must not make the teaching permanently inaccessible.

### 3.2 Concrete feedback, pattern colors, and terminology

Feedback must be deterministic and derived from the evaluated target. No language model generates answer keys or teaching verdicts.

For the saved 7s example, use wording equivalent to:

> Yes. You have two Flowers, four 7 Bams, two 7 Dots, four 7 Cracks, and two Green Dragons. The Green Dragons match the Bams. This line allows any like number, so all the numbered groups can use 7.

Do not claim this exact list for other targets. For wrong answers, name the mismatch in the shown hand, then give the governing rule. For jokers, explain which tile the Joker replaces; for a shifted run, show the actual run; for multiple valid interpretations, use a valid evaluated one consistently. Handle variants, exposures, fixed suits, matching dragons, literal Soap/zero, and concealed eligibility through existing engine semantics. Never infer a verdict from display colors.

**Pattern colors lesson:**

> Colors on a card mark suit relationships. Groups in the same color must use the same suit; different suit colors must use different suits. The printed color does not choose Bams, Dots, or Cracks for you.

Use an original pattern and two legal concrete examples with swapped suit assignments. Explain that red/green Dragon names refer to the physical Dragon, not a free choice of pattern color. “In this example: A = Bams, B = Dots, C = Cracks” may appear as a labelled legend when needed. Show letter/shape labels or accessible text so color is never the only signal. Teach F, D, X, C, year 0, and “any like/consecutive numbers” before asking the user to interpret them. Distinguish D in the printed pattern (Dragon) from suit labels used by the editor.

**Full tile set count question:** “How many copies of the 7 Bam are in a full tile set?” Feedback: “Four. Each numbered tile, Wind, and Dragon has four copies in a standard full tile set.”

**Joker prompt:** “Can a Joker replace a tile in a pair?” Feedback: “No. A pair needs two matching tiles without a Joker. Jokers can replace tiles only in groups of three or more.” This avoids overbroad statements about natural jokers in non-hand contexts.

Use “Cracks (Characters),” “Bams (Bamboo),” and “Dots (Circles)” at first teaching; use the app's established short names afterward. Keep “full tile set,” “group,” “card line,” and “rack” consistent across intros, generated explanations, hints, glossary, and cheat sheet. Do not rewrite unrelated scoring/rule text without a correctness reason.

### 3.3 Practice controls and first actions

- On an untouched path, the next lesson says “Start here.” At the top, show “New to mahjong? Start with Suits and dragons.” after placement as new. Do not auto-open a lesson.
- Today's Deal has the caption “One daily puzzle. Try the lessons first if you're new.” It remains available. Do not change deterministic seeds, replay rules, or rewards.
- The goal fraction includes “lessons today.” A short Profile explanation defines XP as learning points and a streak as days meeting the daily lesson goal.
- Use “Tiles” visibly for the cheat sheet where space permits. Hint is labelled “Hint.” At small widths, provide an accessible compact layout and a visible explanation via Lesson notes; do not force tiny clipped text.
- Before the first scored hint is consumed in a lesson, show one inline explanation with an explicit “Use hint” action: “A hint gives you a clue. Hints lower the XP for a correct first answer. To earn three stars, answer every question correctly the first time without hints.” “Not now” leaves all scoring/answers unchanged. After using one, show “Hint used.” Keep the existing retry XP rate; do not invent an extra hint penalty on a re-asked question. Do not create an extra confirmation on every subsequent question. Explain separately that opening Tiles does not lower the score where allowed.
- Tell the user once that single-choice answers submit on tap, while passing several tiles requires selecting the requested number and tapping Check. Keep the current commit-on-tap behavior.
- B13 remains an observation task. Celebration redesign is outside this wave; preserve the reward sequence unless fixing a reproduced navigation/accessibility bug.

### 3.4 Helper and Game context

Keep experienced paths fast; add concise context to empty states and optional help.

- Charleston: “Before play, choose tiles to pass.” Playing: “During play, compare your rack with your card.” Scout: “Compare opponents' face-up groups with possible hands.” Include the reminder that Helper uses the selected card and cannot see physical tiles automatically.
- Empty Helper: “Add the tiles in your rack, or try an example hand.” Label the existing random-deal action as an example; keep it distinct from the user's real rack and offer Clear. Do not replace an entered rack without existing safeguards.
- For “8 away,” help says “You need eight more tiles to complete this hand. Extra tiles in your rack will be replaced as you play.” Respect the engine's current definition and exposures; do not describe it as eight turns or a win probability.
- A dead result names why it is impossible with the tracked seen/exposed tiles, and offers to review those counts. Missing input must not be presented as certainty about the physical table.
- Assist Off continues to hide the entire Helper tab, as `HelperGate.showsHelperTab` and its tests require. Explain this beside the existing assist picker in Settings/onboarding: “Off hides Hand Helper. Choose Peek or Coach for hand suggestions.” Do not add an inaccessible empty-state message inside the hidden tab or reveal suggestions under Off.
- “Wall game” gets context “No one won before the tiles ran out.” The confirmation still shows the actual rule-book payment effect. Defaults stay Standard; advanced rules and optional money conversion can be expanded when needed.
- At each selected-card control, show the active card name. Selecting a different card never silently deletes the current rack or history.
- Coach tips are scoped to Helper mode and the current task. For example, a Charleston tip may explain passing three tiles; an exposure-entry tip appears only in Playing. If no applicable tip exists, show none. Preserve the existing assist-level/dismissal rules.
- In Charleston after a full rack is entered, show a compact summary such as “Pass 1 of 7 · Right”. Derive it from `CharlestonSequence` and the selected stop/courtesy state rather than a hardcoded denominator. Put expanded pass controls behind a clearly labelled Details action. Keep dealer/East choice discoverable and preserve the existing pass sequence and locked suggestion. The pass recommendation or its reveal action should be visible before advanced tracker controls on the smallest supported phone at normal text size; at AX5 use natural scrolling with a clear heading rather than squeezing text.

### 3.5 Card setup without mandatory notation

Onboarding's own-card intent survives completion and relaunch. Add an additive settings flag such as `pendingCardSetup`, decoded as `false` for old files. Set it when the user explicitly chooses “own card”; choosing Practice/later clears it. Skip before choosing a card must not invent own-card intent; skip after an explicit choice preserves that choice. Never reset placement/progress when finishing or returning. Present a nonblocking “Set up your card” action on the landing screen, leading directly to the Cards method chooser. Keep it available until the user chooses the Practice fallback or activates a usable card; cancelling card creation alone does not clear it. The user can choose “Use the Practice Card for now”; it stays active until another card has at least one usable hand and the user chooses to use it. Existing saved users are not re-onboarded and receive no invented setup reminder. A draft/empty card may be stored through existing behavior, but is never automatically made active by this flow.

Cards → “Add a card” opens a method chooser:

1. “Build hands” — guided entry available in the clarity wave.
2. “Import card text” — the existing notation file flow.
3. “Read a shared QR code” — the existing image/link flow, clearly labelled as a Mahjong Mania QR code.

Do not advertise Scan a printed card until the scanning wave is implemented and passes its gate. The existing photo picker recognizes a QR code in a picture; it does not read the photographed printed hands.

Guided hand entry is a second UI over the existing notation/domain model:

- Set hand name, section, points, and Exposed/Concealed with short descriptions.
- Add/reorder/remove groups; choose tile category, tile count, fixed tile/suit or suit relationship A/B/C. Explain relationship slots with actual preview examples.
- Support year digits/Soap, Winds/Flowers/Dragons, matching-Dragon constraints, any-like/any-consecutive numbers, and existing alternative variants. Do not silently flatten any of these into one fixed hand.
- Preview the line and at least one concrete valid hand. Show a running “N of 14 tiles.” Reject invalid group sizes, contradictory constraints, or zero valid targets through existing core validation.
- When a source expression is not representable by the guided controls, keep it exactly intact and label “Advanced pattern”; open the advanced editor without a lossy conversion. Do not claim the guided editor supports every arbitrary imported expression.
- Keep “Advanced notation” accessible, with a preview, examples, undoable in-memory edits, and the existing copyright note. Round trips between modes preserve meaning, metadata, comments, and unrelated card lines. Existing `CardEditing` remains the write path. Cancel writes nothing; Save writes atomically. No card format replacement or automatic bulk normalization.

**Guided model contract:** map supported groups to existing `TileSpec.number`, `.matchingDragon` and `.fixed`, `SuitRef.variable`/`.fixed`, `GroupSpec`, `PatternVariant` and `Shift`. A/B/C map to existing x/y/z variables and remain pairwise distinct; fixed suit is a separate choice. Support multiple alternatives, year digits including literal Soap, and `.none`/`.consecutive`/`.parity` without changing their engine interpretation. Do not add rules or import private card content to make a preview look plausible. Keep points in the existing 1...500 range with existing quick values. Require 14 tiles per alternative and at least one valid bounded expansion for the complete line. Existing physical/Joker/variant restrictions still apply. Quints may be legal with Jokers; do not reject them simply because the natural tile has four copies.

Each alternative has its own group list/count. Teach “any like numbers” as a shared shift of equal numbers and “consecutive” as a shared shift preserving offsets, not separate random choices for each group. Unsupported decorative tokens or expressions open Advanced with the original text intact; never strip `+`, `=`, `-`, `x`, comments or unknown source to force conversion. Switching modes with unsaved edits offers Apply/Discard/Cancel; validate before applying. For representable expressions, compare canonical semantics and expanded target signatures in tests; whitespace equality alone is not a round-trip test.

## 4. Free scanning feasibility: findings and chosen direction

**Feasible architecture; recognition quality has not been measured.** Free means no per-scan inference fee to the app owner/user. It does not mean zero engineering cost or guaranteed recognition.

Apple Vision performs OCR on the device and returns recognized text/candidates and confidence. VisionKit offers camera document capture. PDFKit can render pages, and PhotosPicker can select existing images. These APIs fit the existing native app and iOS 17 minimum. No cloud service is required for this baseline. Sources are listed in §9.

OCR text alone loses the critical distinction between suit-color groups. The app must separately analyze foreground colors and row layout, preserve small footnotes, and interpret card semantics. OCR confidence is not a probability that a mahjong rule was parsed correctly.

Apple explicitly cautions that recognized text bounding boxes are approximate, and accurate OCR may have word-level rather than character-level boxes. Do not specify “read every glyph's exact color from its OCR box” as a solved API feature. Prototype independent foreground segmentation and color clustering on the normalized source image; use OCR regions as layout hints. If a color boundary/group is unresolved, ask the user to correct it. Never turn red/green/blue printed ink directly into fixed Cracks/Bams/Dots.

Apple's current Foundation Models framework also supports on-device model use and newer image features; available APIs depend on OS and hardware. The installed SDK declares base model APIs at iOS 26 and image-related APIs at iOS 27. Runtime model availability can be blocked by device eligibility, disabled Apple Intelligence, region, or an unready/download-pending model. It cannot be the only path in an iOS 17 app. An optional on-device model may propose row structure or explain a footnote during the experiment, but deterministic validation and user review remain authoritative. Do not require it or ship model weights. No cloud inference or Private Cloud Compute path is selected for either wave. An on-device proposal adapter must never opt into a remote service.

### 4.1 Feasibility experiment and measurable gate

Before implementing the production scanner, create a small local development harness that compares:

- Vision OCR + layout/color analysis + deterministic parsing.
- Optionally the same inputs plus an available on-device model for draft proposals. Report separately; no silent fallback to a server.

Use **30 original test pages** with at least **120 annotated rows**, including at least 20 deliberately unreadable/ambiguous rows. Split 20 development pages / 10 held-out pages before tuning; held-out pages must include at least 30 readable rows and eight deliberately ambiguous/unreadable rows. Include clean image and PDF sources, multi-column layouts, red/green/blue and black ink, different font sizes, grayscale, rotated/skewed photos, shadows/glare, blur, `0/O`, `1/I`, F/D/NEWS, counts and points, X/C, any/consecutive/like rules, matching Dragons, alternatives, and a footnote affecting several rows. Repetition/augmentations of the same card layout must stay in one split. These are targets for the experiment, not measured results.

Define ground truth as canonical line semantics: all variants, numbers, group sizes, suit equality/inequality/fixed-suit constraints, dragon constraints, shift range, points, and concealed flag. Text-string similarity or “14 tiles” alone is insufficient.

Report exact rows correct, rows needing correction, rows omitted, rows correctly flagged, confidently wrong rows, runtime, peak memory, and OS/device/model used. Preserve all source spans and uncertainties. Freeze the supported classes before running held-out evaluation; omitted readable rows in those classes count as failures, and do not move hard rows out of the denominator after seeing results. Required advance gate:

- At least 90% of supported, readable held-out rows produce a semantically exact draft without manual repair; list excluded/unsupported layouts explicitly.
- Every intentionally ambiguous/unreadable held-out row is flagged or rejected, never presented as ready.
- Zero semantically wrong rows labelled ready in the held-out set. This finite result is a release gate, not a guarantee about arbitrary cards.
- No card is saved or activated without review, even when every row is ready.
- Main-thread responsiveness remains good, cancel works, and memory stays bounded. Measure baseline performance on the available simulator and freeze numeric time/memory budgets from the development set before the held-out run. Record physical-device performance separately on the oldest supported test device available; if none is available, leave that owner check open and label simulator measurements honestly. No physical-device speed claim without evidence.

If the gate fails, ship the clarity wave independently. Improve the experiment or restrict scanning to a narrower, clearly labelled assisted workflow (for example one cropped line at a time). Do not ship “scan any card” marketing or silently increase cost/device requirements to meet the gate.

### 4.2 Owner-supplied evaluation samples

Useful first samples: one sharp color photo of a full card, one close-up of a section with footnotes/alternatives, one ordinary imperfect phone photo, and a source PDF if available. The same card at different resolutions is useful for robustness but is not independent layout evidence. Keep a held-out set after initial exploration.

Inspect supplied images in the current conversation first and produce a draft transcription plus an uncertainty list for the owner to check. This is a reference for testing local recognition, not an API benchmark. Do not forward samples to another provider or run paid calls for this wave. Do not put real proprietary card images or their full reconstructed contents into the public repository; commit only original fixtures and aggregate results.

### 4.3 Cost boundary

No provider account, API key, cloud endpoint, attestation/quota server, paid request, or monetization system is to be created. Local failures go to correction/manual entry or an honest unsupported-input message. Any future cloud proposal requires a separate product decision and budget; a cap or hoped-for donations does not make it self-funding. Earlier API price estimates are intentionally excluded from the execution scope.

## 5. Scanning wave: product flow and data contracts

### 5.1 Acquisition and review flow

Cards → Add a card adds “Scan a printed card” with “Take photo,” “Choose photos,” and “Choose image or PDF.” The term “upload” is avoided because the selected files remain on the device.

1. Explain the baseline: “Scan a card you own. We'll make a draft for you to check. Photos and files stay on your device.” Preserve the existing personal-use content policy.
2. Capture/select. Request camera access only on Take photo, with `NSCameraUsageDescription` in project.yml. Use PhotosPicker and the document picker rather than blanket photo-library access. Check scanner/camera support and give Photos/Files alternatives when unavailable or denied. Handle iCloud-only file downloads with a clear offline error; do not claim the app fetched no data if the system is downloading a user-selected source.
3. Preview, rotate, crop, and retain color. Suggest a close, glare-free capture, one panel at a time for a folded card. Do not force black-and-white filters. Select PDF pages before rendering. A text PDF may supply text layout hints, but colored page rendering is still needed; image-only PDFs take the same OCR path. Reject encrypted PDFs with a clear message and offer an unlocked image/PDF, without attempting to bypass protection.
4. Read in a cancellable background task with progress per page/row. OCR/table text is data, never instructions to the app or a model. A malformed file cannot cause network/tool actions, unbounded work, or executable behavior.
5. Review each detected row beside its source crop and page/row number. Show the colored pattern, one example hand, points, X/C meaning, notes/constraints, and any unresolved fields. No model-generated “confidence percentage” UI. Use “Ready to review,” “Needs a check,” and “Can't read this line.”
6. Tap a group to correct text, count, suit relationship, number range, or dragon mapping in the guided editor; compare with the source. Footnotes have explicit scope: line, section, or whole page. Unresolved footnotes/alternatives block the affected row. Never discard a troublesome variant to make a row validate.
7. Every row starts unconfirmed. The user confirms reviewed rows. A summary lists confirmed, unresolved, and excluded counts. Saving only the confirmed rows requires explicit acknowledgement of omitted rows: “Save N hands; leave M out.” There is no silently skipped content.
8. Ask for the card's name/year; never assert issuer identity from a logo. Create one card atomically using existing CardFile/parser validation, then offer “Use this card in Helper and Game Night.” Do not overwrite/merge an existing card in the first scanner release.
9. Cancel leaves existing cards/settings untouched and clears temporary media. Keep the source/draft during the current import session only; closing with edits asks whether to discard the draft. A cold launch does not pretend a half-written card exists. A future resumable draft is separate scope.

### 5.2 Architecture

- App target: Vision/VisionKit, PhotosUI, PDFKit, image decoding, orientation/cropping, foreground/color analysis, optional model adapter, media storage lifetime, and SwiftUI review UI.
- MahjongCore: Foundation-only candidate types, interpretation/constraints, validation and canonical export. No UIKit/Vision/PDFKit/SwiftUI/Combine imports. Existing parser/engine is the authority for a usable hand.
- `ImportDraft` holds source identifiers and candidate lines. Each `CandidateLine` has a stable session ID, raw transcription, source references, proposed semantic fields/variants, unresolved field reasons, and review state. Source references use zero-based page index and normalized numeric rectangles in a documented upright coordinate system, not framework image types. Preserve transforms back to the displayed crop; test rotated sources so a correction never highlights another line.
- Model required fields as unresolved/resolved explicitly; absence is not a default. This includes points, exposed/concealed, group counts, suit relationships, number shifts, variants and footnotes. Confidence may inform review flags but cannot resolve a missing rule. “Ready to review” requires complete, supported and semantically valid fields; the other states retain a specific reason and manual correction action.
- Review states distinguish unconfirmed, confirmed and explicitly excluded. Any semantic edit invalidates that row's confirmation; a page/section footnote edit invalidates every affected row. Recropping/re-reading invalidates affected source proposals and confirmations, with confirmation before replacing edits. Use an import-session/task identity so late OCR/model results from cancelled or replaced work cannot overwrite the current draft.
- Distinguish recognition uncertainty, unsupported notation, and invalid mahjong structure. A valid-but-wrong candidate is possible, so syntax validation never removes the review step.
- Parser output cannot introduce impossible physical counts or expand alternatives without bounds. Reuse existing card/QR limits where appropriate. Never convert black ink uniformly to a single suit variable: Winds, Flowers, fixed symbols, and wildcard suit groups have different meanings.
- Version any newly persisted import/provenance metadata with backward-compatible decoding. Existing 1.0–1.4 cards, sessions, totals and practice progress must retain their meaning. The source/candidate draft itself is session-only; persistence is not required just to attach provenance to an imported card.

### 5.3 Resource limits, privacy and content

Supported initial sources are JPEG, PNG, HEIC and PDF; validate actual decodability, not the filename alone. Initial input caps: 30 MB per import, at most 4 selected pages/photos, decoded sources no larger than 50 megapixels, and at most 120 candidate rows. Reject limits with a useful crop/select-fewer-pages action before allocating full decoded buffers. Downsample/process one page at a time to at most 12 megapixels; do not render a huge PDF page at its unconstrained native dimensions. Release file-provider/security-scoped access and temporary buffers on every success/error/cancel path. These are maximum caps, adjustable downward with measured memory evidence recorded in DECISIONS. Raising them requires a separate resource review.

Color-dependent patterns from grayscale or near-monochrome sources require user-assigned suit relationships. Glare, clipping, missing points/flags, inconsistent constraints, or uncertain footnotes must never be auto-filled from guesses. Explain what to recapture or correct.

The baseline adds no account, per-scan charge, API key, external inference, analytics, remote image retention, or public distribution. No cloud fallback is available. Do not log extracted card contents. Imported images/PDFs and their metadata are temporary local inputs; share/export actions must never attach original source media accidentally. The app continues to ship only its original Practice Card; fixtures and marketing use original content. Scanning a user-supplied card does not give the app rights to publish that card. Retain the existing personal-use notice; do not present this feature as legal permission to redistribute copyrighted cards.

Re-audit camera/photo/file handling, privacy manifest and App Store copy. Offline processing can remain accurately described as local; remove the old “no permissions” claim once camera capture exists. Account for system file-provider downloads in support copy. Reset all data also removes any app-owned temporary draft media. Optional on-device model use must not invoke cloud services. Update privacy text for camera permission without weakening the local-processing guarantee.

## 6. Ordered implementation and release checklists

**One PR per phase, in order.** Phase status is pending until actual evidence exists. No fake screenshots, weakened assertions, silent skipped tests, or credit for a different branch's test run. Preserve unrelated files/worktrees and coordinate exclusive simulator use. Follow `AGENTS.md`; use existing `claude/<topic>` branch naming. File names below are the inspected starting points, not permission to rewrite unrelated architecture.

### 6.1 Common gate for every implementation PR

- [ ] Requirements for this phase implemented; each behavioral fix has a regression test at the lowest suitable level (core, then app model, then UI if necessary).
- [ ] UI driven on an isolated simulator and screenshots inspected. Cover changed flows in light/dark, normal text/AX5, smallest supported phone layout and existing iPad compatibility as applicable. Use Reduce Motion for any changed animations. Record exact device/OS/build and artifact locations.
- [ ] On the final branch, `tools/test.sh` completes successfully; it includes `swift test --package-path Packages/MahjongCore`, XcodeGen and app unit/UI tests. Inspect the build and xcresult diagnostics: zero compiler/analyzer warnings and no unresolved runtime layout warnings. A passing exit code alone is insufficient. Use targeted tests while iterating, then the full gate before pushing/merging. Actual test targets are `MahjongManiaTests` and `MahjongManiaUITests`.
- [ ] SPEC's linked phase box, PROGRESS row and behavior/deviation entries in DECISIONS are updated in this PR. PR body records exact commands/results, warning counts and screenshot evidence. Generated projects and private media/signing artifacts are excluded.
- [ ] Push/open/attach the PR, then merge once local gates pass. CI stays disabled. Record the PR in progress; proceed without asking permission between phases.

Docs-only planning/record updates need no app test run; adding executable fixtures/harness/test code is not docs-only. Preserve existing core coverage requirements; do not move domain logic into a platform target to avoid tests.

### Phase 34 — Beginner audit, prerequisite coverage and teaching

Starting points: `Practice/Curriculum.swift`, `CurriculumUnits.swift`, `TileFacts.swift` in MahjongCore; `LessonSession.swift`, `LessonView.swift`, `LessonIllustration.swift`; Learn content and `AppTests/ContentTests.swift`, `PracticeTests.swift`. New model names may follow existing conventions.

- [x] Verify 1.3 release completion, create `claude/beginner-teaching`, link this approved spec from SPEC §20 and add phases 34–38 to PROGRESS. Include these planning documents in this first PR if still untracked; preserve the earlier 1.3 handoff.
- [x] Run §7 against integrated 1.3 before editing, without answer-revealing launch flags. Record findings B01–B15 as reproduced/resolved/hypothesis with screenshots in `docs/BEGINNER_AUDIT.md`. B13 is observation only. An actual novice study remains an owner follow-up.
- [x] Implement §3.1 orientation/teaching and consistent terminology. Extend the copy as needed to cover the actual generated pools, including current house-rule questions: explain the selected rule rather than teaching a custom rule as universal.
- [x] Add stable concept metadata and a human-readable prerequisite map for all existing scored path exercise types. Enumerate fact IDs and exercise families/difficulties; do not infer completeness from a few sampled random seeds. Preserve pools, exercise IDs, enum order, salts, deterministic generation, grading and review IDs. Teach missing prerequisites in the current or earlier lesson rather than dropping hard questions.
- [x] Implement ordinary-lesson notes with state preserved. Tests show opening/closing does not change exercise/selection/answers/hints/timing-based rewards, XP or progress, and forbidden assessment entry points cannot expose it. Notes must not restart the current question or reset a timer.
- [x] Coverage tests detect a newly introduced untaught concept; human review verifies the copy actually teaches each mapped concept. Backward-compatible progress fixtures load unchanged. Complete the common gate.

### Phase 35 — Explanations that match the shown hand

Starting points: MahjongCore `Practice/CardReadingExercises.swift`, `ExerciseTypes.swift`, `Exercises.swift`, `Engine/EngineTypes.swift`, notation descriptions; pattern/feedback views and Learn card-reading content.

- [ ] Implement §3.2 using the actual generated/evaluated `Target` and concrete `binding`, group counts and Joker substitutions. Retain context in the exercise's deterministic data where necessary; do not re-roll a different target to make explanatory copy.
- [ ] Both `matchesLine` and `whichHand` explanations are covered. Wrong answers identify a true mismatch; multiple legal interpretations choose one evaluated interpretation consistently. No rule verdict comes from presentation colors or generated prose.
- [ ] Add original worked color examples and a visible/non-color suit relationship legend. Label actual suits in ordinary concrete feedback; explain A/B/C only where abstract relationships are being taught/edited. F/D/X/C/0 and shift rules precede their scored use.
- [ ] Regression fixtures cover the 7s example; swapped suit assignments; fixed suits and matching Dragons; literal year Soap/zero; legal and illegal Joker replacement; shifted consecutive/parity bounds; alternatives and concealed/exposure eligibility where exercised. Assert semantic correctness and absence of misleading printed-number descriptions, not just one exact sentence. Existing answer keys and seeds stay unchanged.
- [ ] Visually inspect the worked examples, correct/wrong feedback and hints in both exercise families. Complete the common gate.

### Phase 36 — First actions, Helper context and scorekeeping clarity

Starting points: `PracticeHomeView.swift`, `PathView.swift`, `HeaderStrip.swift`, `LessonSession.swift`, `ProfileView.swift`; Helper views, `HelperGate.swift`, `CharlestonHeader.swift`, `App/Content/Tips.swift`; Game setup/record/scoreboard views.

- [ ] Implement §3.3 labels, Start here and daily/XP/goal context, keeping the existing dashboard hierarchy and next-lesson algorithm. Experienced placement/test-out and Daily Deal remain available with their existing rewards/seeds.
- [ ] First hint confirmation occurs once per lesson attempt, not once per question or permanently across all lessons. “Not now” consumes nothing. “Use hint” calls existing hint logic once; later hints retain existing per-question limits. The existing score/star calculations are unchanged. Test dismiss, double tap, subsequent questions and assessment restrictions. Opening Tiles/notes remains free where permitted.
- [ ] Implement §3.4 mode/distance/dead-reason/selected-card copy, preserve Assist Off's hidden tab and Peek reveal behavior, and filter tips before the unshown-tip choice. Keep tip IDs/dismissal history. Test all three modes, all assist levels, and no-applicable-tip behavior.
- [ ] Compact Charleston tracker derives labels from existing state, supports first/second/courtesy/stop/dealer states, and preserves locked recommendations. With the full rack and keyboard dismissed, the recommendation or reveal action precedes expanded controls and is discoverable on the smallest phone; at AX5 it scrolls naturally. No pass sequence or recommendation algorithm changes.
- [ ] Standard setup and wall-game explanation remain readable without changing defaults, payouts, settlement, undo/history or required recording taps. Any progressive disclosure preserves custom-rule discoverability and saved custom selections. Complete the common gate.

### Phase 37 — Own-card setup and guided hand entry

Starting points: `OnboardingView.swift`, `SettingsStore.swift`, app tab/navigation routing; Cards `CardsListView.swift`, `ImportView.swift`, `LineEditorModel.swift`, `LineEditorView.swift`, `CardEditing.swift`; MahjongCore notation/parser/expansion APIs; existing editor, store and QR tests.

- [ ] Implement §3.5 pending intent, direct method chooser and explicit Practice fallback. Test all three onboarding choices, Skip before/after choice, cancellation, relaunch, successful activation, old settings missing the new field, and existing users not being re-onboarded. Practice lessons continue using their original Practice Card; selected user cards serve existing Helper/Game use.
- [ ] Guided entry is the default for a new hand; existing advanced lines safely open in the appropriate mode. Support every specified representable group/relationship/variant/shift combination. Explain counts, points and exposed/concealed with preview and a clear 14-tile check.
- [ ] Foundation-only domain adapters/semantic checks belong in MahjongCore; app form/navigation state remains in the app. Reuse parser/engine limits and CardEditing's source-preserving writes. Do not build a second rule engine or change notation meaning.
- [ ] Tests cover add/remove/reorder, all supported TileSpec/SuitRef/Shift cases, alternatives and metadata, semantic/target round trips, unsupported source retained unchanged, invalid/zero-target lines, quints with Jokers, cancel, atomic save failure, comments/unrelated/invalid source-line preservation, and no empty-card activation. Existing file/QR import and links still work.
- [ ] Walk onboarding own-card → build original hand without notation → preview → save → explicit activate → Helper selected card, including dark/AX5. No printed-card scan action or camera permission in 1.4. Complete the common gate.

### Phase 38 — Integrated 1.4 QA and automatic TestFlight release

- [ ] Create `claude/release-1-4` after phases 34–37 merge. Complete §7 end to end; update `docs/BEGINNER_AUDIT.md` with before/after evidence and unresolved owner items. Fix reproduced release blockers with regression coverage; defer unapproved redesigns.
- [ ] Set `MARKETING_VERSION` to `"1.4"` in `project.yml`, regenerate, and keep build numbering under the uploader. Update TestFlight/WhatToTest, release handoff/history, AppStore What's New, review notes and any screenshots/listing claims affected by changed UI. Run the existing listing checker and regenerate/inspect any affected screenshot set. No scanning claims, camera permission or pricing changes.
- [ ] Verify all old saved fixtures, progress, cards, sessions, settings, rule presets, shared QR/text imports and active-card selection survive. Existing iOS 17 availability and Foundation-only core remain intact; use actual available destinations and check introduced API availability.
- [ ] Finish the common full local/visual gate on the final phase branch, record evidence and merge the phase PR. Check all five PRs are on main. Leave actual upload/processing boxes open until confirmed.
- [ ] Perform §6.2 from clean, up-to-date main. Confirm exact version/build processing `VALID`, then record the result/PRs/test evidence in PROGRESS/DECISIONS. Never press Submit for Review. Leave physical-device/VoiceOver/haptics/TestFlight-install boxes for the owner.

### 6.2 Release procedure for each completed wave

The owner's standing instructions explicitly authorize commit/push/PR/merge and automatic TestFlight upload after every approved complete wave. No new permission request is needed. This does not authorize submitting for App Store review. Read current `RELEASING.md` and uploader usage first; 1.3 is expected to improve dry-run artifact preservation, so verify the actual interface rather than assuming an option exists.

1. Start from clean main containing every wave PR, no concurrent mutations or other session's release. Preserve untracked planning work in an appropriate PR first; never discard it to pass preflight. Recheck remote state/version and exact app's unused next build number.
2. Run the dry export via `zsh -ic` and preserve its exported IPA outside Git using the documented mechanism (expected `--dry-run --ipa-output <absolute-path>`). Never read/print the credential-loading shell files, environment, keys, JWTs or signing values. Do not disable test/signing/preflight gates.
3. Validate that preserved IPA inside a credential-loaded `zsh -ic` shell with `xcrun altool --validate-app -f <ipa> -t ios --apiKey "$ASC_KEY_ID" --apiIssuer "$ASC_ISSUER_ID"`. Keep sensitive raw output private; report redacted diagnostics. Correct actual validation problems in a tested PR, merge, and repeat export/validation.
4. Run the real `zsh -ic 'tools/upload_testflight.sh'`. Preserve its build-number bump and its own required test gates. If protection creates a build-bump PR, open/attach/merge that PR.
5. Query App Store Connect for the exact app/version/build and wait with sensible backoff for `VALID`; upload acceptance alone is not release completion. Investigate processing failures. Record the build and evidence only when true. A still-processing build is reported as still processing, not shipped. Do not submit for review or silently mark owner device tasks complete.

### Phase 39 — Local scanner experiment (after 1.4)

- [ ] Separate `claude/card-scan-feasibility` PR. Produce `docs/CARD_SCAN_EVALUATION.md`, an original annotated corpus/manifest and a local reproducible harness. No production entry point, paid request or network fallback. Platform recognition stays in an Apple-target harness/app adapter; semantic comparison stays Foundation-only.
- [ ] Freeze the layout-disjoint dev/held-out split, ground truth, supported input classes, gate denominator and numeric resource budgets before the final held-out run (§4.1). Report every row, omissions and ready-but-wrong errors, plus runtime/memory/OS/device. Do not remove hard examples after seeing results.
- [ ] Owner samples stay private and are never required to manufacture synthetic passing evidence. Original fixtures can establish correctness/reproducibility; results from synthetic files alone do not establish camera-photo quality. Report missing real-device/sample evidence honestly.
- [ ] Production phases 40–42 may proceed only when the fixed semantic/ambiguity gates pass for a documented useful supported class. If they fail, stop production implementation and record the actual failed metrics; a narrowed flow needs an amended explicit scope/benchmark before continuing. Do not add a server or spend money. Notify the owner of this concrete decision.
- [ ] Common gate applies to executable additions. Add 1.5/39–42 linked checklists to SPEC/PROGRESS when this separate wave begins. A passing experiment is not a public scanner release.

### Phase 40 — Bounded local media acquisition and interpretation

- [ ] Implement §5 capture/Photos/Files/PDF, support/permission errors, crop/rotation/color, normalized source rectangles, background cancellation and strict limits. Platform code remains in the app; domain candidates/interpreters/validators remain in core.
- [ ] Keep the flow behind an internal development gate until review/save is complete in Phase 41. No advertised unfinished import method. Use iOS 17 baseline APIs; an optional available local model is an enhancement, never a sole path or server fallback.
- [ ] Test decoded-size checks, selected-page limits, corrupt/locked/provider errors, unsupported camera, cancellation after each processing stage and no stale result updates. Process one bounded page at a time and measure against the Phase 39 budgets. Complete the common gate.

### Phase 41 — Source comparison, corrections and atomic card creation

- [ ] Implement §5 candidate states and review UI, every field/footnote/alternative, guided correction, invalidated confirmation after semantic edits, explicit omissions and atomic create-new-card. At least one confirmed usable row required; zero-row save is disabled. Existing card/history/settings remain unchanged on failure/cancel.
- [ ] Require every row's confirmation even if recognition is exact. “Ready to review” is not “correct.” Edited/corrected rows pass existing semantic validation; unresolved fields block confirmation. No auto-activation or silent merging.
- [ ] Exercise original images/PDFs end to end plus injected acquisition errors, share/export content isolation and temp cleanup on cancel, successful save, reset and abandoned sessions. Stale app-owned media from a killed import is removed at next launch without touching system originals. Complete the common gate.

### Phase 42 — Scanner release QA and automatic 1.5 TestFlight

- [ ] Re-run the unchanged held-out benchmark against final production interpretation and require §4.1 gates. Complete every scenario in §8, offline and with optional model absent. Check supported-source messaging matches measured evidence. Physical camera quality/speed remain explicitly unverified until owner evidence exists; do not claim otherwise or mark those boxes done.
- [ ] Re-audit camera purpose string, permission timing, privacy manifest/policy/support/listing/App Privacy answers and local-only data claims. Publish the approved factual site updates through the existing workflow. No new issuer branding, proprietary built-in content or unmeasured “any card” promise.
- [ ] Set version 1.5 via project.yml, update TestFlight/release/listing artifacts, run common gate, merge every scan phase and perform §6.2 automatically. Keep owner physical-device and App Store submission actions open.

## 7. First-time-player walkthrough and acceptance script

Start from a fresh app container on a simulator not used by another build. Do not erase the owner's app data or another agent's simulator. No answer-revealing test launch flags. Capture before/after states and record exact build/commit, OS, device, text size, and any facilitator help. The approved methods are direct GUI interaction or stepwise XCTest navigation with visual screenshot review, as specified in §7.1; neither method substitutes a green test run for the walkthrough.

1. **Understand the app:** complete onboarding as “I'm new.” State what a winning hand is, what Practice does, and where real-table scoring lives. Identify the next action without a tour.
2. **First lesson:** read the teaching, answer deliberately right and wrong, use a hint after reading its cost, open Tiles/lesson notes and return to the exact same question. Confirm all tested facts were taught. Finish and find the next lesson.
3. **Second and third lessons:** explain Flower interchangeability, Soap as zero, Joker restrictions, East and first-pass direction before answering their scored questions. Confirm a novice is not forced to guess untaught facts.
4. **Read a card:** complete Unit 2 examples. Explain F/D/X/C, distinguish printed colors from physical suit colors, and identify why a 7s hand matches a printed 1s like-number pattern. Repeat with a different suit permutation and with a wrong Dragon/Joker-in-pair example.
5. **Helper:** enter a real-sized rack, remove a tile, choose the appropriate mode, reveal suggestions, explain N away, and locate the selected card and tile guide. Inspect partial/full rack states; show a dead-hand reason using tracked counts.
6. **Game:** add three/four people, keep Standard rules, record self-pick and discard, record a wall game, correct one hand, and explain settle-up. The primary recording path remains fast.
7. **Cards:** choose own-card onboarding, defer once, return to setup; build an original hand without notation; inspect the advanced representation; cancel and save edits; make the valid card active; confirm Helper uses it. Import a QR picture via the separate method.
8. **Learn and recovery:** find a term without losing the current task; relaunch and verify saved progress/cards/history; inspect dark, small iPhone, AX5 and iPad compatibility layouts. Hand-run VoiceOver and haptics remain physical-device owner tasks.

Observe one actual beginner and one experienced player on the resulting TestFlight build before final App Store submission where practical. Record hesitation, incorrect mental models, task completion and required help. Do not equate passing scripted UI tests with novice comprehension.

### 7.1 Audit method when the Simulator window is unavailable

The requirement is an expert walkthrough of the running simulator app with visual inspection, not use of a particular desktop application. A missing Simulator.app does not require restoring/reinstalling Xcode before continuing if CoreSimulator, XCTest interaction and real screenshot capture work. Use either direct interaction in the Simulator window or **stepwise XCTest navigation with agent-reviewed screenshots**. Name the actual method accurately; the latter is a screenshot-reviewed expert walkthrough, not a manual GUI session or a novice participant study.

For the screenshot-reviewed method:

1. Reuse/create an isolated simulator and fresh container for the unassisted baseline. Launch the actual integrated 1.3 build without answer-revealing flags, question/lesson-completion shortcuts or pre-unlocked beginner progress. Use ordinary visible controls. Read the shown question and teaching to choose answers; do not inspect hidden answer markers or the answer key to traverse the beginner path.
2. Work through all eight §7 tasks in small observable segments. Capture the intro, each new question/control type, deliberately correct/wrong feedback, hint before/after, lesson completion/reward navigation, and the important Helper/Game/Cards/recovery states. Capture scrolled content where needed. Inspect images with the image-viewing tool before judging the screen; assertions and accessibility dumps supplement but do not replace visual review. Use what was observed to choose the next action and investigate confusing states.
3. In BEGINNER_AUDIT, map every task to actual actions, screenshot paths, observed copy/layout, confusion and finding IDs. An existing scripted flow counts only for the checkpoints whose screenshots were inspected and whose setup/limitations were recorded. Passing a suite alone does not complete the audit. Keep setup-assisted secondary cases separate from the fresh beginner journey; a fixture may make a rare dead-hand case reproducible but cannot stand in for onboarding or Units 1–2.
4. The baseline audit is complete when every applicable task has a documented observed outcome, including an identified defect or absent 1.4 capability. Lesson notes/guided entry do not yet exist in 1.3: record those gaps rather than demanding those future features work before implementation. If a case cannot be exercised, record the exact case/reason and use a bounded isolated setup where appropriate; do not silently mark it passed. Then implement Phase 34. Re-run the same tasks against 1.4 in Phase 38 to require the new behaviors to pass.
5. Continue to label device-only checks and actual-user comprehension as unverified. If XCTest cannot operate a required flow or screenshots cannot be captured/read, report that specific remaining limitation. Do not stop solely because the Simulator desktop window is missing.

## 8. Scan acceptance scenarios

- Clean original multi-column color image and color PDF: all reviewed fields survive canonical serialize/parse and match annotated semantics.
- Phone photo with perspective, rotation and mild shadow: crop/review works, unsupported rows flagged, no false certainty.
- Grayscale, glare over a group, ambiguous `0/O`, missing X/C/points, and a footnote spanning rows: user sees exactly what must be resolved; no invented values.
- File too large, excessive page count, corrupt/locked PDF, source deleted by provider, camera denial/unsupported simulator, missing Apple Intelligence, cancelled selection/recognition/review, and interrupted save: readable error/recovery, no existing-data loss.
- A source containing instructions such as “ignore previous rules” remains inert text, never a model/tool instruction or imported action.
- Repeated scan of the same source creates no duplicate unless the user explicitly saves another card; no silent merge into existing data.
- Source colors preserve equality/inequality independently of physical suit artwork; matching Dragons and literal year zeros are validated. Alternative patterns are all preserved or explicitly unresolved.
- Core import logic runs under `swift test` on Linux. UI uses injected original local fixtures; physical camera quality and speed require real-device evidence before advertising them as verified.

## 9. Primary technical sources (checked 2026-10-31)

- [Apple: Recognizing text in images](https://developer.apple.com/documentation/vision/recognizing-text-in-images) — on-device recognition, candidates, confidence and layout information. Markdown retrieved directly when the web renderer could not display it.
- [Apple: VNRecognizedText.boundingBox(for:)](https://developer.apple.com/documentation/vision/vnrecognizedtext/boundingbox(for:)) — approximate boxes; fast path character precision versus accurate path word precision; not an exact image-processing segmentation API.
- [Apple: VNDocumentCameraViewController](https://developer.apple.com/documentation/visionkit/vndocumentcameraviewcontroller) — document capture images and runtime support check; available since iOS 13.
- [Apple: PDFPage.draw(with:to:)](https://developer.apple.com/documentation/pdfkit/pdfpage/draw(with:to:)) — PDF page rendering.
- [Apple: PhotosPicker](https://developer.apple.com/documentation/photosui/photospicker) — selected-photo loading, including unavailable/iCloud source errors.
- [Apple: Foundation Models framework](https://developer.apple.com/foundation-models-framework/) — current on-device and image capabilities; cloud access has separate conditions and is not chosen here.
- [Apple: Generating content and performing tasks with Foundation Models](https://developer.apple.com/documentation/foundationmodels/generating-content-and-performing-tasks-with-foundation-models) — runtime availability and fallback requirements.

The installed iPhoneOS27.2 FoundationModels Swift interface was also inspected for OS availability. Neither these documents nor the SDK establishes accuracy on mahjong cards. That is the purpose of Phase 39.
