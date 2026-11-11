# Card-scan feasibility evaluation (1.5, Phase 39)

Date: 2026-11-10. Spec: [NEXT_WAVES_SPEC.md](NEXT_WAVES_SPEC.md) §4–§6 and §8. Harness: `tools/CardScanHarness` (macOS, local only; no network, accounts, servers or paid calls; no CI). Recognition runs in the harness. Semantic comparison, the row interpreter and the evaluator are Foundation-only code in `Packages/MahjongCore/Sources/MahjongCore/Scan/` with `swift test` coverage.

## 1. Verdict

**The beta gate (§4.1) is NOT met. Production phases 40–42 should not proceed as specified.** The safety rules held on the synthetic held-out set; the accuracy and quality-check rules did not, and real photos of the owner's own card were far below the bar.

| §4.1 criterion | Result | Verdict |
|---|---|---|
| ≥ 60% of supported readable held-out rows give a semantically exact draft | **18 of 55 = 32.7%** (dev set, used for tuning: 65 of 97 = 67.0%) | **Fail** |
| …per format (held-out, any state) | text-layer PDF 6/7 = 85.7%; screenshot 6/10 = 60.0%; image-only PDF 2/4 = 50.0%; grayscale 1/6 = 16.7%; photo of a screen 1/4 = 25.0%; retyped table 2/12 = 16.7%; phone photo 0/12 = 0.0% | 2 of 7 formats at or above 60% (small n) |
| Every ambiguous/unreadable held-out row flagged or rejected | 10 of 10 (dev 30 of 30) | Pass |
| Zero semantically wrong rows labelled ready | **0** on synthetic held-out and dev. On the owner's real photos: **2 wrong-but-ready rows** across 11 photos (plus 1 on the 1600 px web graphic) | Pass on synthetic, **fail on real photos** |
| Quality check rejects ≥ 90% of poor held-out sources | 10 of 10 = 100% | Pass |
| Quality check accepts every clean source | **8 of 10** held-out (2 clean digital pages wrongly flagged "glare"); 20 of 20 dev; on real owner images it flagged 5 of 11 phone photos "cut off" and 3 of 3 web images "glare/cut off" | **Fail** |
| No card saved or activated without review | Not applicable to the experiment (no save path exists) | n/a |
| Time and memory budgets (frozen from dev) | Held-out: median 0.6 s/page (budget 2 s), max 0.8 s (2 s), peak 242 MB (500 MB): within budget. Owner full-size photos: 0.8–3.6 s (one photo over the 2 s budget), peak 210–460 MB. macOS release build on an M2 Max; **not** an iOS simulator or device | Within budget on the corpus; over on one real photo; device speed unverified |

"Exact" means the draft's canonical semantics equal the ground truth (all variants, groups and counts, suit equality/inequality, dragon constraints, shift, points, concealed flag), whether or not the row was flagged. The stricter "exact and labelled ready" figure is 4 of 55 (7.3%) on held-out, because the interpreter deliberately flags every `0` read from a picture, every section-implied number rule and every guess.

## 2. What was built

- **Core (`MahjongCore/Scan`)**: `ScanSemantics` (canonical key: suit variables renamed over all permutations, groups/variants as sets, ignores names), `ScanRowInterpreter` (tokens with ink class → draft hand through the app's own `Notation.parseLine`; a row is `ready` only when nothing is guessed), `ScanEvaluator` and `ScanTally` (pair drafts to truth, count exact / flagged / omitted / ready-but-wrong / ambiguous-ready), `ScanGateVerdict`. 25 `swift test` cases.
- **Harness (`tools/CardScanHarness`, `tools/scan_eval.sh`)**: `HandPool` (original hands, validated by the parser), `PageRenderer`/`Imaging` (CoreGraphics + CoreImage), `CorpusBuilder`, `SourceLoader` (ImageIO thumbnail decode capped at 12 MP; PDFKit text layer and a 200 dpi capped render), `OCR` (Vision `VNRecognizeTextRequest`, accurate, language correction off; `VNDetectDocumentSegmentationRequest` + `CIPerspectiveCorrection`), `InkAnalyzer` (independent foreground colour analysis, black reference measured per page, hue clusters per page), `LayoutAnalyzer` (line, gap and column detection, tails that trail or lead, footnotes, section titles; no fixed geometry), `QualityCheck`, `Pipeline` (second reading at another scale before a row may be `ready`), `Freeze`, `Evaluation`, `OwnerRun`. 11 harness tests.
- Colour is never mapped to a fixed suit: same ink within a hand means the same suit variable, different inks mean different variables.
- Vision reported a confidence of 1.00 on every word in this corpus, so confidence cannot gate "ready". A row is `ready` only if a second recognition at a different scale yields the same hand.
- Not done: the optional on-device Foundation Models comparison (not attempted; no cloud path was considered). The text-layer-versus-OCR cross-check from §4.4 (text layer wins on characters, layout inconsistency flags the row) was not built; PDFs with a text layer simply use the layer.

## 3. Corpus (original, no real card content)

30 pages, 192 annotated rows (152 readable, 40 deliberately ambiguous). Page images are regenerated from the committed seed and manifest with `tools/scan_eval.sh generate` (the 90 MB of rendered media is git-ignored); `corpus/manifest.json` holds every page, layout, row and ground-truth line.

| Split | Pages | Readable rows | Ambiguous rows | Layouts |
|---|---|---|---|---|
| Development | 20 | 97 | 30 | L1 3-column trifold, L2 gridded table, L3 2-column with notes below, L4 large single column with row numbers |
| Held-out | 10 | 55 | 10 | L5 2-column landscape with merged `X25` and plain-text notes, L6 1-column with section bars, `1)` row numbers and a ruled tail |

Layouts and hands are disjoint between splits (enforced by a test). Formats (dev / held-out pages): phone photo 4/2, text-layer PDF 3/1, image-only PDF 3/1, screenshot 3/2, grayscale 3/1, photo of a screen 2/1, retyped table 2/2. Held-out has one page for four formats, not two, because the 10-page split cannot hold two of each; this is stated rather than hidden. Content covers red/green/blue and black ink (and a second palette), multi-column and single-column pages, six font families, F/NEWS/dragons, counts and points, X/C, matching dragons (`DD/x`), alternatives (`-or-`), `+ =` operators, `0` Soap, shift by section title (section scope) and by `*`/`**` footnotes (page scope), and rotated, keystoned, shadowed, warm-lit, noisy photos. Ambiguity kinds: missing points, missing X/C, the letter O printed for a zero, a blotted group, a faded group.

Poor sources for the quality check: 2 each of heavy blur, very dark, large glare, card mostly cut off and not a card, per split (10 dev, 10 held-out).

### Frozen before the held-out run

`tools/CardScanHarness/corpus/freeze.json`, committed in `85b9754` before any held-out result existed: the page lists for both splits, the SHA-256 of `manifest.json` (the held-out command refuses to run if it or the thresholds change), supported formats (all seven), unsupported layouts (fixed-suit notation, patterns split over several printed lines, text rotated more than ~15° after page correction), the gate denominator (every readable held-out row of every format, omissions count as failures, no row removed afterwards), the quality and ink and layout thresholds, and the budgets: 2 s median and 2 s max per page, 500 MB peak (2× and 1.5× the dev maxima of 0.75 s and 307 MB, rounded up). No row was moved after the run.

## 4. Results

### Development set (used for tuning; not evidence of generalisation)

| Format | Pages | Readable | Exact | Exact and ready | Needs correction | Omitted | Ready but wrong | Ambiguous | Flagged or rejected | Ambiguous shown ready |
|---|---|---|---|---|---|---|---|---|---|---|
| phone photo | 4 | 18 | 15 (83.3%) | 7 | 1 | 2 | 0 | 6 | 6 | 0 |
| text-layer PDF | 3 | 17 | 16 (94.1%) | 7 | 1 | 0 | 0 | 4 | 4 | 0 |
| image-only PDF | 3 | 15 | 12 (80.0%) | 4 | 1 | 2 | 0 | 5 | 5 | 0 |
| screenshot | 3 | 14 | 12 (85.7%) | 4 | 0 | 2 | 0 | 4 | 4 | 0 |
| grayscale | 3 | 13 | 3 (23.1%) | 0 | 6 | 4 | 0 | 5 | 5 | 0 |
| photo of a screen | 2 | 12 | 3 (25.0%) | 0 | 2 | 7 | 0 | 3 | 3 | 0 |
| retyped table | 2 | 8 | 4 (50.0%) | 0 | 1 | 3 | 0 | 3 | 3 | 0 |
| **All** | 20 | 97 | **65 (67.0%)** | 22 | 12 | 20 | 0 | 30 | 30 | 0 |

Median 0.6 s per page, peak 307 MB. Quality check: 20 of 20 clean accepted, 10 of 10 poor rejected.

### Held-out set (one run, after the freeze)

| Format | Pages | Readable | Exact | Exact and ready | Needs correction | Omitted | Ready but wrong | Ambiguous | Flagged or rejected | Ambiguous shown ready | Median s | Peak MB |
|---|---|---|---|---|---|---|---|---|---|---|---|---|
| phone photo | 2 | 12 | 0 (0.0%) | 0 | 3 | 9 | 0 | 2 | 2 | 0 | 0.8 | 221 |
| text-layer PDF | 1 | 7 | 6 (85.7%) | 4 | 0 | 1 | 0 | 1 | 1 | 0 | 0.1 | 63 |
| image-only PDF | 1 | 4 | 2 (50.0%) | 0 | 0 | 2 | 0 | 1 | 1 | 0 | 0.7 | 242 |
| screenshot | 2 | 10 | 6 (60.0%) | 0 | 1 | 3 | 0 | 2 | 2 | 0 | 0.6 | 170 |
| grayscale | 1 | 6 | 1 (16.7%) | 0 | 3 | 2 | 0 | 1 | 1 | 0 | 0.6 | 213 |
| photo of a screen | 1 | 4 | 1 (25.0%) | 0 | 0 | 3 | 0 | 1 | 1 | 0 | 0.7 | 220 |
| retyped table | 2 | 12 | 2 (16.7%) | 0 | 1 | 9 | 0 | 2 | 2 | 0 | 0.6 | 168 |
| **All** | 10 | 55 | **18 (32.7%)** | 4 (7.3%) | 8 | 29 | **0** | 10 | 10 | **0** | 0.6 | 242 |

OS/device: macOS 26.6.2, Apple M2 Max, 32 GB, release build of the harness, each source in its own process (peak resident memory includes the Vision models). Swift 6.4.2. No physical device or iOS simulator figures.

Held-out figures per format rest on one or two pages and a handful of rows; the confidence intervals are very wide. The gap between dev (67%) and held-out (33%) is the real finding: the interpreter and layout analysis were tuned on four layouts and did not generalise to two unseen ones. What failed on unseen layouts, read off the held-out run: tails printed as one token (`X35`, even `x25` lower-case) were not always split or recognised, row numbers written `1)` were not stripped (this was knowingly left as a held-out stressor; the dev layout with `1.` was handled), colour words in brackets that Vision read with mixed bracket shapes (`(green]`) were not attached, note columns read as pattern text, and ordinary OCR slips (`55` read as `53`) on small print. None of the failures was silently wrong, which is the design intent, but the user would be correcting most rows by hand.

### Quality check (§5.1 step 3a prototype)

Measures: sharpness (99.5th percentile local gradient), paper brightness, clipped-white fraction (glare), paper touching the frame or OCR words on the frame edge (cut off), median word height (too far), count of tile-like words (not a card). Thresholds were tuned on the dev set, frozen, and applied unchanged. Digital pages (screenshots, PDF renders) are exempted from glare when more than 85% of pixels are clipped white.

| | Dev | Held-out |
|---|---|---|
| Clean sources accepted | 20 / 20 | **8 / 10** (screenshot L6 and retyped L6 flagged "glare") |
| Poor sources rejected (blur 2, dark 2, glare 2, cut off 2, not a card 2) | 10 / 10 | 10 / 10 |

The "screen lines" (moiré) message was not implemented, so it is unmeasured. Several poor sources received an additional first-listed message that is wrong (a dark photo also reported "too blurry"); the message order needs work. On real images the check over-rejects (see §5).

## 5. Owner samples (aggregates only; nothing from the card is recorded here)

Ground truth: the owner's 2026 key (55 hands, 0 parse errors).

- **11 phone photos** (5712×4284 or 4032×3024, whole trifold visible among table and floor): the quality check accepted 5, flagged 5 "cut off" and rejected 1 as "doesn't look like a card". Across the 11 photos the harness drafted **16 exact rows out of 605 key-row slots (2.6%)**; the best single photo drafted 10 of 55 (18%) and the union over all photos covers 10 of 55. 3 candidates were labelled ready, **2 of them semantically wrong** (one of those a spurious extra row). Of 347 detected candidates, 280 were "can't read this line" and 64 "needs a check". Most common reasons: suit colour not readable, no points found, no X/C found, not a valid 14-tile hand, unrecognised text. Time 0.8–3.6 s per photo (one over the 2 s budget), peak memory 210–460 MB (release build, M2 Max).
- The gap to the synthetic dev result is large and expected: small print on a wide scene, a laminated cover with reflections, dotted leaders, long notes in parentheses, `-or-` alternatives, red X/C marks and three narrow panels per photo. The spec asked for close-ups of each panel; none are in this set.
- **Web images** (3): all are digital graphic renditions of 2026-style hands (a tracker-style layout with checkboxes, different fonts and ink colours, three columns), not photos: 1600×1600 AVIF, 794×794 AVIF and a 508×393 JPEG (the small ones are low resolution). They are layout-different from the synthetic corpus and from the owner's printed card. Drafted exactly 0 (794 px), 7 (1600 px) and 1 (508 px) of the 55 key rows; the 1600 px image produced one wrong-but-ready row. The quality check flagged all three as glare and/or cut off, which is wrong for clean digital images: a false-reject class to fix. Used for "flags honestly / doesn't crash" and the key comparison only.
- **AVIF**: ImageIO on macOS 26 decoded both AVIF files through the same bounded loader as JPEG. AVIF is not in the §5.3 supported list. Proposal (recorded in DECISIONS): accept it as a decode-only addition if the iOS 17 Simulator or a device decodes it through `CGImageSource` (not verified here; ImageIO AVIF support is believed to start at iOS 16), validating decodability rather than the filename, and otherwise return the existing "unsupported format" message.

## 6. Recommendation for phases 40–42

1. Do not build phases 40–42 as specified. Both accuracy gates failed on the one layout-disjoint test that exists, and real photos are an order of magnitude below the bar. The spec's own rule applies: stop production implementation, record the actual metrics (this document), do not add a server or spend money, and amend the scope explicitly before continuing.
2. A narrowed, clearly labelled scope is plausible but needs a new explicit benchmark first. The strongest evidence is for **PDFs with a text layer** (dev 94%, held-out 6/7, zero wrong, fastest) and clean digital screenshots (dev 86%, held-out 6/10). Even there the held-out evidence is one to two pages. Image-only PDFs, phone photos, grayscale, photos of screens and retyped tables should be labelled limited or left to a one-row-at-a-time assisted flow (crop one line, read it, confirm) rather than a page draft.
3. Before any narrowed build: (a) fix the quality check's false rejects on digital and wide real images; (b) make the interpreter tolerate merged tails, row numbers and bracket variants, and re-benchmark on **new** layouts, because dev tuning did not transfer; (c) get per-panel close-ups.
4. The review-first design (every row confirmed, ambiguous rows never ready) held up on synthetic data and is worth keeping; it is what turns a 33% draft into a safe, if tedious, import. The zero-wrong-ready rule did not hold on real photos, so ready-row confirmation ("Confirm all ready hands") should not be offered for photo sources until it does.

## 7. Not verified

- Speed and memory on a physical iPhone, on the oldest supported device, or in the iOS Simulator (the harness is macOS-only); main-thread responsiveness and cancellation (no UI exists).
- Optional on-device Foundation Models comparison (not run).
- Camera-quality evidence beyond the 11 owner photos; older-year cards; grayscale, photocopy and photo-of-screen copies of a real card; PDFs of a real card. These would help most next: **close-up photos of each panel, flat and in good light**, any **text-layer PDF** of a card the owner is entitled to use (none was supplied), and an older-year card with its key.
- Fixed-suit notation, rotated pages beyond ~15°, multi-page sources and the §5.3 caps in a UI.

## 8. Reproduce

```
tools/scan_eval.sh generate            # corpus media from the seed (manifest hash must match freeze.json)
tools/scan_eval.sh eval dev
tools/scan_eval.sh eval held-out       # needs corpus/freeze.json; refuses if manifest or thresholds changed
tools/scan_eval.sh quality held-out
SCAN_PRIVATE=<path to private/card-scans> tools/scan_eval.sh owner   # prints aggregates only
tools/scan_eval.sh test                # harness tests; core: swift test --package-path Packages/MahjongCore
```

Machine-readable aggregates: `tools/CardScanHarness/results/*.json`. Owner-sample output is never written to disk by the harness.
