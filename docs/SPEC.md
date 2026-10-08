# Mahjong Mania — Product & Engineering Spec (v1 rebuild)

> **Audience:** the engineer/agent implementing this app (e.g. Claude Sonnet) and the product owner.
> **Status:** approved plan for a from-scratch rebuild. The phases in §13 are written so each one can be done as a separate PR, in order.
> **Last updated:** 2026-10-08

---

## 0. How to use this document (read first, implementer)

1. Read the whole document once before starting. Then do **one phase from §13 per PR**, in order. Do not jump ahead. Later phases depend on the types and modules built in earlier ones.
2. Each phase lists **tasks**, **files**, and **acceptance criteria**. A phase is done only when every acceptance box is true and `npm run check` passes (typecheck + lint + tests; set up in Phase 0).
3. **Expo SDK is pinned to 55.** Do not upgrade the SDK, React, or React Native. Install native/Expo packages **only** with `npx expo install <pkg>`, so versions match SDK 55. `AGENTS.md` says: read the versioned docs at https://docs.expo.dev/versions/v55.0.0/ before writing code. If that site is unreachable from your sandbox, use the versions pinned in §6.2 and read the package's bundled `README`/`.d.ts` files in `node_modules`.
4. Code in `src/domain/**` is **pure TypeScript**: no React, no React Native, no Expo imports. It must be fully unit-tested. Most of the app's correctness lives there.
5. When the spec gives an exact algorithm, signature, string, or number, use it exactly. When it says "suggested", you may adjust as long as the acceptance criteria still hold.
6. Do not ship the official NMJL card's hands or branding anywhere in the app (see §2.4). The built-in card is the **original Practice Card** in §9.6.
7. Keep a running checklist: tick the boxes in §13 in the same PR that completes them.

---

## 1. Product vision

**One line:** A table-side companion for **American Mahjong** that keeps score for experienced players and coaches new players. It gives exactly as much help as you ask for.

### 1.1 Who it's for

| Persona | What they want | What they must NOT get |
|---|---|---|
| **Seasoned player** ("just keep score") | Fast scorekeeping in ≤5 taps per hand, correct payouts, money settle-up, game-night history | Hints, nagging, clutter |
| **Improving player** | Occasional checks: "what am I closest to?", "can I call this?", "what might she be going for?" | Hand-holding they didn't request |
| **Brand-new player** | Learn the tiles, how to read a card, which hand to aim for, what to pass in the Charleston, why | Jargon without explanation |

### 1.2 Design principles

1. **Help is opt-in and progressive.** There is a global **Assist Level** (Off / Peek / Coach), and nothing is revealed above that level unless the user taps to reveal it. (§11.3)
2. **The physical game comes first.** People play with real tiles at a real table. The app must never slow the table down: big tap targets, one-handed use, no required typing during play, and the screen stays awake during a game.
3. **Correct before clever.** A wrong payout or a bad hint loses trust right away. The domain logic is pure, deterministic, and heavily tested.
4. **Calm, warm, uncluttered UI.** Ivory, jade, and red, like a real tile set. One primary action per screen. Progressive disclosure.
5. **Bring your own card.** The official card is copyrighted and changes every year. The app ships an original Practice Card and makes it fast to enter the user's own card.
6. **Offline-first, private.** No account and no network. All data stays on the device.

### 1.3 v1 feature pillars

1. **Game Night (Scorekeeper):** players, sessions, record hands, automatic NMJL-style payouts, house rules, dealer rotation, undo/edit, money settle-up, history, and player stats.
2. **Hand Helper (Assistant/Coach):** enter your tiles and see your closest hands, what you still need, which tiles are dead, Charleston pass suggestions, discard suggestions, a "Can I call this?" check, and a Scout mode that reads opponents' exposures for danger tiles.
3. **Cards:** the built-in Practice Card, user-entered cards with a compact notation and a live preview, bulk paste import, and share/export.
4. **Learn:** a rules quick reference, a tile guide, how to read a card, the notation guide, a glossary, and two practice drills (Pick-a-Hand, Charleston Pass).

### 1.4 Explicitly out of scope for v1 (see §15 for future ideas)

Online multiplayer or a playable digital game vs bots, camera/OCR recognition of tiles or cards, accounts and cloud sync, 5-player games with a rotating sitter, betting, wagering, and in-app purchases.

---

## 2. Research summary

### 2.1 Market (Oct 2026)

- American Mahjong is in a real boom with younger players. Yelp named mahjong a top trend for 2026, citing a reported ~4,000%+ YoY rise in searches for mahjong clubs and an ~819% rise for lessons. Eventbrite reported +179% US mahjong events from 2023 to 2024. NPR covered the Gen Z/Millennial surge in Jan 2026. Clubs in SF and Denver draw 40–200 people per session. ([NPR](https://www.npr.org/2026/01/24/nx-s1-5678606/why-a-century-old-tile-game-is-suddenly-drawing-younger-players), [Fox Business](https://www.foxbusiness.com/media/gen-z-fueling-explosive-return-200-year-old-strategy-craze), [Admissions Angle](https://admissionsangle.substack.com/p/genz-mahjong-skills))
- **The competitors are mostly *digital game* apps** (Real Mah Jongg, Mahj Parlour, MahJongg4Fun, I Love Mahj, Mahjong 4 Friends, Eight Bam practice). They play the game *on the phone*. Several have "hand suggestions"/"matching hands" inside their own game. ([Bam Good Time 2026 roundup](https://bamgoodtime.com/blog/best-american-mahjong-apps-2026), [Eight Bam](https://eightbam.com/), [MahJongg4Fun](https://apps.apple.com/us/app/mahjongg4fun-american-mahjong/id6746219026))
- **The in-person companion niche is thin.** Score tracking for American Mahjong is mostly manual "enter the score afterwards" apps or generic calculators. Analyzers exist as web tools (e.g. learnmahjong.app: enter your rack, see the best hands to chase and what to discard). Riichi has good score-manager apps; American does not. **Our gap: one calm app that keeps score at a real table *and* coaches on demand.**
- Known pain point from reviews: scoring totals that don't match the card, because multipliers are confusing (self-pick ×2, jokerless ×2). We show the payment breakdown before saving and explain it.

### 2.2 What players need (synthesised)

- **Scorekeeping:** correct multipliers, who threw the winning tile, jokerless bonus, wall games, running totals, settle-up in money (common stakes are about 1¢/point, so a 25-point hand is a quarter), history and bragging rights.
- **Configurable house rules.** Groups agree on scoring rules before play. Defaults should match the standard NMJL card rules, and anything beyond those must be a toggle.
- **Beginner struggles:** (a) reading the card notation, (b) locking onto one hand too early instead of keeping 2–3 options through the Charleston, (c) not knowing what to pass, (d) not recognising dead hands, and (e) Singles & Pairs hands, which must be decided early because jokers can't be used and you can't call. ([Sloperama Charleston advice](https://sloperama.com/mahjongg/column2/column630.html), [Charleston strategy guide](https://mahjongg.ai.studio/charleston/strategy/))
- **Intermediate needs:** "Can I call this tile?", "Is my hand dead?", "What is the player across from me building?" (defensive play).

### 2.3 Rules that the software must model (authoritative list in §5)

152 tiles; hands of 14; jokers only in groups of 3+; Soap (White Dragon) doubles as zero; dragons "match" suits (Red ↔ Cracks, Green ↔ Bams, White ↔ Dots); hands are marked Exposed (X) or Concealed (C); the payout rules are in §10. ([NMJL FAQ](https://nationalmahjonggleague.org/faq.aspx), [Wikipedia: American mahjong](https://en.wikipedia.org/wiki/American_mahjong), [Scoring in Mahjong](https://en.wikipedia.org/wiki/Scoring_in_Mahjong), [The Mahjong Line – Big Card scoring](https://themahjongline.com/pages/the-big-card-scoring-points-and-money))

### 2.4 Legal / content constraint (important)

The NMJL card's presentation is copyrighted, and other apps avoid distributing it (I Love Mahj ships its own card). Game rules themselves are generally not copyrightable. ([Mondaq: copyright issues in the mah jongg craze](https://www.mondaq.com/unitedstates/copyright/1825446/copyright-issues-in-americas-fast-growing-mah-jongg-craze), [I Love Mahj KB](https://ilovemahj.com/kb/67000755029))

**Therefore:**
- Ship only the **original Practice Card** (§9.6). Never ship NMJL lines, and never use "NMJL"/"National Mah Jongg League" in the app name, icon, or marketing.
- Users may enter hands from a card they own, for personal use. Show a one-time note in the card editor: *"Enter hands from a card you own. Please don't publicly share copyrighted cards."*
- Rules text in Learn must be our own original wording.

---

## 3. Assessment of the current repo → verdict: **rebuild from scratch**

| Area | Finding |
|---|---|
| Runs at all? | **No.** `package.json` `main` is `index.ts` → `App.tsx`, which is still the Expo placeholder. The `app/` (expo-router) and `src/` code is never loaded. `expo-router`, `expo-sqlite`, and `@react-native-async-storage/async-storage` (imported in `app/_layout.tsx`) are **not installed**. |
| Features | Only a tile tracker that ranks "custom hands" plus collection CRUD/share. **No scorekeeping at all**, even though that is the core of the vision. |
| Rules correctness (engine) | Missing **Flowers** completely (8 tiles in every set). No constraint that suit groups use **different** suits (two-suit hands could resolve to the same suit). No dragon↔suit matching. No Soap-as-zero. Invents "literal JOKER slots", which American Mahjong doesn't have. Joker eligibility is a per-slot flag the user must set instead of the rule "groups of 3+". Treats all 14 tiles as one pool, so there is no concept of exposures, concealed hands, or dead tiles. |
| Hand entry | The editor only builds concrete tiles one by one. You can't express "any suit" or "any consecutive numbers", which make up most of a real card. |
| Code quality | Duplicate `tileKey` implementations, ID-generation bugs in `CardIngestionService.ingestManual` (builds `collectionId` from a different random value, then rebuilds), SQLite schema heavier than needed, no tests, no lint config. |
| UI | Dark navy theme with emoji tab icons and text-label tiles ("1C", "RD"). Tracker, list, and keyboard are crammed onto one screen. |
| Reusable ideas | The idea of a hand as **groups with suit-variable constraints** is right and is kept (redesigned as the notation in §9). "Scout" mode (filter hands by exposures) is a good idea and is kept (§10.6). |

**Decision:** delete everything under `app/`, `src/`, `App.tsx`, and `index.ts`, plus `README.md.bak`, and rebuild following this spec. Keep `assets/` (icons get replaced in Phase 9), `AGENTS.md`, `CLAUDE.md`, and `.claude/`.

---

## 4. Feature specification (what, not how)

### 4.1 Game Night (Scorekeeper)

- **Players roster:** name, avatar colour (auto-assigned from palette, editable), created date. Reused across sessions. Archive (soft delete) keeps history.
- **New session:** pick **3 or 4** players (from roster or "+ Add player" inline), set seat order (play order around the table), choose the starting dealer (East, default first seat), optional active card (for picking hand names/values), rules preset (Standard or a saved custom ruleset), money on/off and ¢/point.
- **Active session scoreboard:** players in seat order showing name, current East badge, net points, and net money (if enabled). Primary button **Record a hand**, secondary **Wall game**, overflow menu: Undo last, Add adjustment, Rules, End game night.
- **Record a hand** (target: ≤5 taps for an experienced player):
  1. Winner (player chips).
  2. How: **Self-pick** or **Discard**. If Discard → "Who threw it?" (chips of the other players).
  3. Hand: either pick a **line from the active card** (searchable list grouped by section, which shows its points) or **enter points** (quick chips 25/30/35/40/45/50/55/60/65/70/75 plus a stepper).
  4. **Jokerless** toggle. Auto-disabled and explained when the chosen line has no group of 3+ (Singles & Pairs): "Already jokerless — no bonus".
  5. **Payment preview** with each player's +/− and a plain-English explanation ("Bea threw the tile: pays double (50). Others pay 25."). **Save**.
- **Wall game:** one tap, then confirm. No payments (or a house-rule payment, §10.2). The dealer advances.
- **Adjustment:** move N points from player A to player B with a note (for penalties or house rules).
- **Undo last / edit any hand:** editing recomputes that hand's payments with the session's rules snapshot.
- **Dealer rotation:** after each Mahjong or wall game, East passes to the next seat in play order. Show "East: Bea" on the scoreboard.
- **End game night → Summary:** final standings, biggest hand, most wins, settle-up list ("Cy pays Alex $1.25"), Share (system share sheet with a text summary).
- **History:** list of past sessions (date, players, winner). Open one for its read-only scoreboard and hand log.
- **Player stats:** per player across all sessions (§10.5).
- **Keep awake:** the screen stays on while an active session screen is focused (setting, default on).

### 4.2 Hand Helper

- **Card picker** (active card) and an **Assist Level** chip.
- **Mode tabs:** **Charleston** (13 or 14 tiles, no exposures yet), **Playing** (rack + my exposures + seen tiles), **Scout** (opponents' exposures).
- **Tile input keyboard** (§11.5): tap to add, tap a rack tile to remove, counts per tile type, can't exceed physical counts.
- **Results ("Closest hands"):** top hands ranked (§10.4). Each shows the pattern with matched tiles highlighted, "N away", points, X/C badge, missing tiles, ⚠ Dead badge (impossible because the needed tiles are all seen), and "Jokerless possible" ✨.
- **Coach panel** (Coach level only, or when revealed):
  - Charleston: "Pass these 3" with one-line reasons, plus a "keep options open" tip naming the 2–3 families you're strongest in.
  - Playing: "Discard suggestion" (top 3) with reasons, and **Can I call it?** (pick the tile just discarded → verdict).
  - Scout: "Possible hands for each opponent" and **danger tiles** (don't throw) vs safer tiles.
- **Seen tiles tracker** (Playing mode, collapsible): tap counters for tiles discarded/exposed by others. This feeds dead-tile detection.
- The rack persists if you leave the tab (cleared with the "Clear" button).

### 4.3 Cards

- **Card list:** Practice Card (built-in, read-only, "Duplicate to edit"), user cards (name, year, line count). Actions: New card, Import (paste), Duplicate, Rename, Delete (confirm), Set active.
- **Card detail:** sections → lines, each rendered as a coloured pattern (§11.6) with points and an X/C badge; search by name/section; tap a line → **Line detail** (big pattern view, plain-English description, variants, and "Practise this hand" which opens the Helper with this line pinned).
- **Line editor** (user cards): notation text field with a quick-insert key row, live validation errors (with position), live pattern preview, plain-English description, fields for section (pick or new), name (optional), points, Exposed/Concealed, Shift (None / Any consecutive (step 1) / Keep odd-even (step 2)).
- **Bulk import:** paste a multi-line card file (§9.5). Shows a per-line result (✓ or error) and imports the valid lines into a new or existing card.
- **Export/share:** produces the card file text (§9.5) → system share sheet / copy to clipboard.

### 4.4 Learn

- **Rules quick reference** (original text; facts listed in §12.1).
- **Tile guide:** every tile type, with nicknames and counts in a set.
- **How to read a card:** families, colours = suits, X vs C, points, the "any consecutive" idea, Singles & Pairs.
- **Notation guide:** the app's notation (§9) with interactive examples (each example rendered with `HandPattern`).
- **Glossary** (§12.2).
- **Drills:** *Pick-a-Hand* (deal 13 random tiles → user picks the line they'd aim for → app reveals the top 3 with distances and explains) and *Charleston Pass* (deal 13 → user selects 3 tiles to pass → compare to the engine's suggestion and explain). Show a streak counter. Use a seeded deal so "Try again" replays the same deal.

### 4.5 Onboarding & settings

- **Onboarding (first launch, 3 screens, skippable):** Welcome → "How much help do you want?" (Off/Peek/Coach as 3 big cards with examples) → "Which card?" (Use the Practice Card / I'll enter my own card / Decide later).
- **Settings:** Assist level, Theme (System/Light/Dark), Haptics on/off, Keep screen awake during games, Default rules (opens rules editor), Money (on/off, ¢ per point, currency symbol), Tile sort (by suit / as entered), About (version, disclaimer, credits), **Reset all data** (double confirm).

---

## 5. Domain rules reference (the engine must follow these)

### 5.1 Tiles (152 total)

| Kind | Key(s) in code | Copies | Notes |
|---|---|---|---|
| Cracks 1–9 | `1C`…`9C` | 4 each (36) | a.k.a. Craks/Characters. Colour: red |
| Bams 1–9 | `1B`…`9B` | 4 each (36) | Bamboo. Colour: green. The 1 Bam is traditionally a bird |
| Dots 1–9 | `1D`…`9D` | 4 each (36) | Circles. Colour: blue |
| Winds | `N` `E` `W` `S` | 4 each (16) | |
| Red Dragon | `R` | 4 | matches Cracks |
| Green Dragon | `G` | 4 | matches Bams |
| White Dragon / **Soap** | `0` | 4 | matches Dots; **also used as zero** (e.g. in 2026) |
| Flowers | `F` | 8 | all flowers are interchangeable |
| Jokers | `J` | 8 | wild, with the restrictions below |

`TILE_KEYS` order (used for sorting and the keyboard): `1C…9C, 1B…9B, 1D…9D, N, E, W, S, R, G, 0, F, J`.

### 5.2 Hands and groups

- A winning hand is **exactly 14 tiles** matching one line on the card.
- Group sizes: single (1), pair (2), pung (3), kong (4), quint (5), sextet (6). A quint of a non-flower tile needs at least 1 joker (only 4 copies exist), and a sextet at least 2.
- **Jokers may substitute only in groups of 3 or more.** Never in singles or pairs. So a hand made only of singles/pairs (Singles & Pairs family) is always jokerless.
- **Suit variables:** on a card, different colours within a line mean *different* suits, and the same colour means the *same* suit. Which actual suit maps to which colour is the player's choice. ⇒ Our variables `x`, `y`, `z` must bind to **pairwise-distinct** number suits.
- **Matching dragon:** a dragon written in a suit's colour means the dragon that matches that suit (Red↔Cracks, Green↔Bams, Soap↔Dots).
- **Soap as zero:** in year hands such as `2026`, the 0 is a White Dragon and carries no suit.
- **"Any consecutive / any like numbers":** the numbers shown on the card are an example. The player may shift all of them by the same amount, as long as they stay within 1–9 (§9.3 `shift`).
- **Exposed (X) vs Concealed (C):** in an X hand, the player may call discards to complete groups of 3+ and expose them. In a C hand, the player may only call the final (Mahjong) tile. Any exposure in a C hand makes that line impossible.
- **Calling:** a discard may be called to complete a pung/kong/quint/sextet, which is then exposed. Singles and pairs may only be called when that tile completes Mahjong.

### 5.3 Turn and Charleston facts used by Learn and Helper (not enforced by the engine)

- East (dealer) starts with 14 tiles, everyone else with 13. East discards first. Play passes to the right (counter-clockwise).
- **Charleston:** first Charleston is mandatory: pass 3 to the **right**, 3 **across**, 3 to the **left**. Any player may stop before the second Charleston. Second Charleston: **left**, **across**, **right**. On the last pass of each Charleston a player may "blind pass" (pass on 1–3 tiles just received, unseen). Then an optional **courtesy pass** across of 0–3 tiles, by agreement between the two players opposite each other (the lower number agreed wins). **Jokers may never be passed.**
- **Joker exchange:** on your turn you may swap the natural tile a joker stands for out of any exposure (yours or an opponent's) and take the joker.
- **Dead hand:** a player whose hand can no longer be made legally (e.g. wrong exposures, wrong tile count) stops playing but still pays the winner.
- **Wall game:** the wall runs out with no winner → no payments (by default), redeal, and the deal passes.

Learn text must phrase table procedures as "the standard way" and remind the user that their card's printed rules and their group's house rules take precedence.

---

## 6. Architecture & tech stack

### 6.1 Stack decisions

| Concern | Choice | Why |
|---|---|---|
| Framework | Expo SDK **55** (React 19.2, RN 0.83), TypeScript strict | already chosen; matches AGENTS.md |
| Navigation | **expo-router** (file-based) with JS `Tabs` + nested `Stack`s | standard; avoid `unstable-native-tabs` |
| State | **zustand 5** stores | tiny and simple; easy for agents to work with |
| Persistence | zustand `persist` + `createJSONStorage(() => Storage)` from **`expo-sqlite/kv-store`** | no schema to manage; data volume is small (< 1 MB) |
| Graphics | **react-native-svg** for tile glyphs and icons | crisp tiles, no image assets |
| Icons | `@expo/vector-icons` (Ionicons) for chrome/tab icons | no emoji icons |
| Animations | **react-native-reanimated** 4 (light use: tile add/remove, sheet) | |
| Gestures | react-native-gesture-handler | required by reanimated/router |
| Haptics | expo-haptics | tile taps, save |
| Keep awake | expo-keep-awake | game screen |
| Sharing | React Native `Share` API + expo-clipboard | text export |
| Fonts | system font (SF/Roboto). Optional: `@expo-google-fonts/fraunces` for the display title only | warm feel without much weight |
| Tests | **jest-expo** + **@testing-library/react-native** | |
| Lint | **eslint-config-expo** (`npx expo lint`) + Prettier | |
| Web | react-native-web + react-dom (installed) | lets agents screenshot screens with Playwright on web; not a shipping target |

### 6.2 Pinned versions (from `expo@55.0.24/bundledNativeModules.json`)

Install with `npx expo install` (this resolves the versions below automatically):

```
expo-router ~55.0.14          expo-sqlite ~55.0.16          expo-haptics ~55.0.14
expo-keep-awake ~55.0.8       expo-clipboard ~55.0.13       expo-linking ~55.0.15
expo-constants ~55.0.16       expo-splash-screen ~55.0.21   expo-system-ui ~55.0.18
expo-font ~55.0.7             expo-status-bar ~55.0.6       @expo/vector-icons ^15.0.2
react-native-svg 15.15.3      react-native-reanimated 4.2.1 react-native-worklets 0.7.4
react-native-gesture-handler ~2.30.0  react-native-screens ~4.23.0  react-native-safe-area-context ~5.6.2
react-native-web ~0.21.0      react-dom 19.2.0              jest-expo ~55.0.17
eslint-config-expo ~55.0.1
```

Plain npm dev/runtime deps (`npm i`): `zustand@^5.0.15`; dev: `@testing-library/react-native@13.3.3` + `react-test-renderer@19.2.0` (exact React version; RNTL 14 needs a different renderer, so don't use it), `prettier@^3`, `eslint@^9` (`eslint-config-expo@55` peers with `eslint >=8.10`).

### 6.3 Folder structure

```
app/                                   # routes only: thin, compose feature components
  _layout.tsx                          # root Stack, providers, theme, onboarding gate, fonts
  onboarding.tsx
  settings.tsx                         # presented as modal
  rules-editor.tsx                     # modal; edits default or session rules (param ?sessionId)
  (tabs)/
    _layout.tsx                        # Tabs: game, helper, cards, learn
    game/
      _layout.tsx                      # Stack
      index.tsx                        # Game home
      new.tsx                          # Session setup
      [sessionId]/index.tsx            # Scoreboard + hand log
      [sessionId]/record.tsx           # Record/edit hand (modal; ?handId= for edit)
      [sessionId]/summary.tsx          # End-of-night summary
      history.tsx
      players/index.tsx
      players/[playerId].tsx           # player stats
    helper/
      _layout.tsx
      index.tsx
    cards/
      _layout.tsx
      index.tsx
      import.tsx
      [cardId]/index.tsx
      [cardId]/line/[lineId].tsx       # line detail
      [cardId]/edit.tsx                # line editor (?lineId= for edit, none = new)
    learn/
      _layout.tsx
      index.tsx
      [topic].tsx                      # rules | tiles | reading | notation | glossary
      drill-hand.tsx
      drill-charleston.tsx
src/
  domain/                              # PURE TS, no RN imports, 100% unit tested
    tiles.ts                           # TileKey, constants, helpers, sorting, labels
    random.ts                          # seeded PRNG (mulberry32), shuffle
    wall.ts                            # full 152-tile wall, deal
    notation/
      types.ts
      parse.ts                         # parseLine, parseCardFile
      format.ts                        # serializeLine, serializeCardFile
      describe.ts                      # plain-English description
    engine/
      types.ts
      expand.ts                        # CardLine -> Target[] (all bindings)
      evaluate.ts                      # Target x PlayerView -> Evaluation
      rank.ts                          # rankHands
      live.ts                          # live tile counts, dead detection
      suggest.ts                       # suggestPasses, suggestDiscards, checkCall
      scout.ts                         # scoutOpponents
      index.ts                         # public API + memoised analyzer
    scoring/
      types.ts
      rules.ts                         # RuleSet, STANDARD_RULES
      payout.ts                        # computePayments
      settle.ts                        # settleUp
      stats.ts                         # player & line stats
      session.ts                       # pure reducers: addHand, editHand, undo, dealer rotation
    cards/
      practiceCard.ts                  # the built-in card (source text + parsed)
  store/
    storage.ts                         # kv-store JSON storage adapter
    settings.ts  players.ts  sessions.ts  cards.ts  helper.ts
  ui/
    theme/tokens.ts  theme/ThemeProvider.tsx  theme/useTheme.ts
    components/                        # Button, Card, Chip, Segmented, Sheet, Stepper, Toggle, ListRow,
                                       # EmptyState, Avatar, Badge, ScreenHeader, Screen, SectionHeader,
                                       # Tile, TileRack, TileKeyboard, HandPattern, MoneyText, PointsText
  features/
    game/  helper/  cards/  learn/  onboarding/   # feature components & hooks used by routes
  content/
    rules.ts  tiles.ts  reading.ts  notation.ts  glossary.ts  tips.ts
  test/
    setup.ts                           # jest setup, kv-store mock
```

Path alias: `@/*` → `src/*` (tsconfig `paths`; expo supports tsconfig paths natively).

### 6.4 Conventions

- Function components and hooks only. Named exports (except route files, which need a default export).
- `StyleSheet.create` with theme tokens via `useTheme()`. No hard-coded colours outside `tokens.ts`.
- IDs: `newId(prefix)` in `src/domain/random.ts`, returning `${prefix}_${Date.now().toString(36)}${random base36 6 chars}`. Domain functions that need IDs take them as parameters, or take an injected `idFn`, to stay deterministic in tests.
- Money is stored as **integer cents**, points as integers.
- Every pressable has an `accessibilityRole` and `accessibilityLabel`. Min hit target 44×44.
- No `any`. Narrow with discriminated unions.

---

## 7. Data model (TypeScript)

```ts
// src/domain/tiles.ts
export type NumberSuit = 'C' | 'B' | 'D';                 // Cracks, Bams, Dots
export type NumberValue = 1 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9;
export type NumberKey = `${NumberValue}${NumberSuit}`;
export type HonorKey = 'N' | 'E' | 'W' | 'S' | 'R' | 'G' | '0';
export type TileKey = NumberKey | HonorKey | 'F' | 'J';

export const TILE_KEYS: readonly TileKey[];               // order per §5.1
export const TILE_COPIES: Record<TileKey, number>;        // 4, F:8, J:8
export function isNumberKey(k: TileKey): k is NumberKey;
export function suitOf(k: NumberKey): NumberSuit;
export function valueOf(k: NumberKey): NumberValue;
export function numberKey(v: NumberValue, s: NumberSuit): NumberKey;
export function dragonFor(s: NumberSuit): 'R' | 'G' | '0';  // C->R, B->G, D->0
export function sortTiles(keys: TileKey[]): TileKey[];    // by TILE_KEYS index
export function tileName(k: TileKey): string;             // "5 Dot", "North", "Red Dragon", "Soap (White Dragon)", "Flower", "Joker"
export function tileShort(k: TileKey): string;            // "5D", "N", "R", "0", "F", "J"
export type TileCounts = Partial<Record<TileKey, number>>;
export function countTiles(keys: TileKey[]): TileCounts;
```

```ts
// src/domain/notation/types.ts
export type SuitVar = 'x' | 'y' | 'z';
export type SuitRef = { kind: 'var'; v: SuitVar } | { kind: 'fixed'; s: NumberSuit } | { kind: 'none' };
export type TileSpec =
  | { t: 'num'; value: NumberValue; suit: Exclude<SuitRef, { kind: 'none' }> }
  | { t: 'dragon'; suit: Exclude<SuitRef, { kind: 'none' }> }   // matching dragon (D/x, D/c)
  | { t: 'fixed'; key: HonorKey | 'F' };                         // N E W S R G 0 F
export interface GroupSpec { tile: TileSpec; count: number }     // 1..8
export type Token = { kind: 'group'; group: GroupSpec; start: number; end: number; tokenIndex: number }
                  | { kind: 'op'; op: '+' | '=' | '-' | 'x'; start: number; end: number };
export interface PatternVariant { groups: GroupSpec[]; tokens: Token[]; source: string }
export type Shift = 0 | 1 | 2;                                   // 0 none, 1 any consecutive/like, 2 parity-preserving
export interface CardLine {
  id: string;
  section: string;
  name?: string;
  points: number;
  concealed: boolean;
  shift: Shift;
  variants: PatternVariant[];      // >= 1, from '|' alternatives
  source: string;                  // canonical serialized line (§9.4)
}
export interface Card {
  id: string;
  name: string;
  year?: number;
  builtIn: boolean;
  lines: CardLine[];               // order = display order; sections derived from order of first appearance
  createdAt: number;
  updatedAt: number;
}
export interface ParseError { code: ParseErrorCode; message: string; start: number; end: number }
export type ParseErrorCode =
  | 'EMPTY' | 'BAD_CHAR' | 'MISSING_SUIT' | 'SUIT_NOT_ALLOWED' | 'BAD_SUIT' | 'TILE_COUNT'
  | 'TOO_MANY_OF_TILE' | 'BAD_POINTS' | 'BAD_EXPOSURE' | 'BAD_FLAG' | 'SHIFT_NO_NUMBERS'
  | 'SHIFT_OUT_OF_RANGE' | 'TOO_MANY_FIELDS' | 'GROUP_TOO_BIG';
```

```ts
// src/domain/scoring/types.ts
export interface Player { id: string; name: string; color: string; archived: boolean; createdAt: number }
export interface RuleSet {
  id: string; name: string;
  discarderMultiplier: number;        // 2
  othersOnDiscardMultiplier: number;  // 1
  selfPickMultiplier: number;         // 2
  jokerlessMultiplier: number;        // 2
  jokerlessBonusForNoJokerLines: boolean; // false: Singles&Pairs-type lines get no jokerless bonus
  wallGame: { kind: 'none' } | { kind: 'everyonePaysWinnerless'; points: number }; // see §10.2
  money: { enabled: boolean; centsPerPoint: number; currencySymbol: string };     // default {false, 1, '$'}
}
export type HandRecord =
  | { kind: 'mahjong'; id: string; createdAt: number; dealerId: string;
      winnerId: string; discarderId: string | null;           // null = self-pick
      cardId?: string; lineId?: string; lineLabel?: string;   // label snapshot e.g. "Even Climb"
      basePoints: number; jokerless: boolean; lineHasNoJokerGroups: boolean;
      payments: Record<string, number>;                       // playerId -> +/- points; sums to 0
      note?: string }
  | { kind: 'wall'; id: string; createdAt: number; dealerId: string; payments: Record<string, number>; note?: string }
  | { kind: 'adjustment'; id: string; createdAt: number; dealerId: string; fromId: string; toId: string; points: number;
      payments: Record<string, number>; note?: string };
export interface Session {
  id: string; createdAt: number; endedAt: number | null;
  seatIds: string[];          // 3..4 player ids in play order
  startDealerIndex: number;
  cardId: string | null;
  rules: RuleSet;             // SNAPSHOT copied at creation; editing session rules re-computes all hands
  hands: HandRecord[];        // chronological
}
```

```ts
// Persisted store shapes (src/store/*). All persisted with `version` + `migrate`.
settings: { version: 1; assistLevel: 'off' | 'peek' | 'coach'; theme: 'system' | 'light' | 'dark';
            haptics: boolean; keepAwake: boolean; tileSort: 'suit' | 'entered';
            defaultRules: RuleSet; savedRules: RuleSet[]; onboardingDone: boolean;
            activeCardId: string; cardNoticeSeen: boolean }
players:  { version: 1; players: Player[] }
sessions: { version: 1; sessions: Session[]; activeSessionId: string | null }
cards:    { version: 1; userCards: StoredCard[] }   // StoredCard = { id, name, year?, text: string (card file §9.5), createdAt, updatedAt }
helper:   { version: 1; mode: 'charleston' | 'playing' | 'scout'; rack: TileKey[]; exposures: TileKey[][];
            seen: TileCounts; opponents: { label: string; exposures: TileKey[][] }[]; pinnedLineId: string | null }
```

User cards are **persisted as card-file text** and parsed on load (memoised by `updatedAt`). This keeps storage format-stable and the share/export trivial. The built-in Practice Card is never persisted; it is parsed from source at startup and has id `practice-v1`.

---

## 8. Non-functional requirements

- **Performance:** `analyze()` (rank all lines for a rack) must take **< 30 ms** on a mid-range phone for a 60-line card. Add a Jest benchmark test that fails if 200 runs on the Practice Card exceed 3 s in CI (generous). Precompute `Target[]` per card once (memoise by card id + updatedAt).
- **Startup:** < 1.5 s to interactive. Hide the splash screen after stores have hydrated.
- **Accessibility:** every tile has a label (`tileName`). Support Dynamic Type up to 1.3× without clipping critical controls. Contrast ≥ 4.5:1 for text. Never use colour as the only signal for suits: every tile also shows its suit glyph, and patterns also show suit letters on request (toggle "Show suit letters" in pattern views, default off).
- **Offline:** no network calls anywhere.
- **Data safety:** all store writes are atomic per store. Bump the store `version` and implement `migrate` on any shape change.
- **Orientation:** portrait (phones). Tablets get the same layout with a max content width of 640.

---

## 9. Hand notation ("MahjNotation") — the heart of Cards and the engine

Goal: a compact, card-like text format that is easy to type on a phone and unambiguous to parse. The line editor helps with a key row, so users rarely type it from memory.

### 9.1 Line grammar

```
line      := pattern ( WS? '|' WS? pattern )* WS? ';' WS? points WS? ';' WS? exposure ( WS? ';' WS? name? ( WS? ';' WS? flags )? )?
pattern   := item ( WS item )*
item      := group | op
op        := '+' | '=' | '-' | 'x'          # decorative only (shown in pattern, ignored by engine). 'x' only as standalone token "x"
group     := body ( '/' suit )?
body      := char+                           # see 9.2; split into maximal runs of identical chars
char      := '0'..'9' | 'F' | 'N' | 'E' | 'W' | 'S' | 'R' | 'G' | 'D'
suit      := 'x' | 'y' | 'z' | 'c' | 'b' | 'd'
points    := integer 1..500
exposure  := 'X' | 'C'
name      := any text without ';' (trimmed; empty allowed)
flags     := flag ( WS flag )*
flag      := 'shift' | 'shift2'
```

- Tokens are separated by one or more spaces. Leading/trailing whitespace is ignored. Parsing is case-sensitive, so lowercase suit letters and uppercase tile letters don't collide.
- Fields after `points ; exposure` are optional: `… ; 25 ; X` is valid.

### 9.2 Group bodies

- A body is split into **maximal runs of the same character**. Each run becomes one group, with `count` = run length.
  - `2222` → kong of 2. `FF` → pair of flowers. `2026` → singles 2, 0, 2, 6. `NEWS` → singles N, E, W, S. `112233` → pairs of 1, 2, 3. `11222` → pair of 1 + pung of 2.
- The body's `/suit` applies to every number group and `D` group in that body. `0`, `F`, winds, `R`, `G` ignore it (no error). So `2026/x` means 2x, Soap, 2x, 6x.
- Character meanings:
  - `1`–`9`: number tile. **Requires** a suit (`MISSING_SUIT` if absent: "Number tiles need a suit: add /x, /y, /z (any suit) or /c, /b, /d (Cracks, Bams, Dots)").
  - `0`: Soap/White Dragon (as zero or as white dragon). Never takes a suit.
  - `F` Flower, `N` `E` `W` `S` Winds, `R` Red Dragon, `G` Green Dragon (concrete).
  - `D`: **matching dragon** of the body's suit. Requires a suit (`D/x` = the dragon matching suit x; `D/c` = Red).
- Suits: `x`, `y`, `z` are **variables** that bind to *distinct* number suits. `c`, `b`, `d` are fixed Cracks/Bams/Dots. A pattern may mix fixed and variable suits. A variable must then also differ from every fixed suit used in that pattern variant. (Example: if `/c` is used, `x` cannot be Cracks.)
- Max group size: 8 for `F`, 6 otherwise (`GROUP_TOO_BIG`).
- Per-variant validation:
  - Total tiles = 14 (`TILE_COUNT`, message: "This hand has N tiles; a hand needs 14").
  - Tile supply: the parser calls `expandLine` (§10.1). Bindings that need more copies of a tile than exist (plain need > copies, or total need > copies + 8) are silently dropped. For example, `Triple Year` cannot use x = Dots, because `DD/x` would then need 5 Soaps. If **no** binding survives for a variant → `TOO_MANY_OF_TILE` ("This hand needs more {tile} than a set has").
  - Variable suits: at most 3 distinct variables, and (vars + distinct fixed suits) ≤ 3 (`BAD_SUIT`).

### 9.3 Shift (any consecutive / any like numbers)

- `shift`: every number digit 1–9 in the line (all variants) may be shifted by the same integer `k` (positive or negative), as long as every shifted digit stays within 1–9. `0` (Soap) never shifts. The written digits are the "example".
- `shift2`: same, but `k` must be even (keeps odd/even parity, e.g. "any odd like numbers").
- `SHIFT_NO_NUMBERS` if a shift flag is set but the line has no 1–9 digits.
- `k = 0` is always included.

### 9.4 Canonical serialization

`serializeLine(line)` → `variants.map(v => v.source).join(' | ') + ' ; ' + points + ' ; ' + (concealed ? 'C' : 'X') + (name || shift ? ' ; ' + (name ?? '') : '') + (shift ? ' ; ' + (shift === 1 ? 'shift' : 'shift2') : '')`.
Each variant's `source` is its tokens joined by single spaces, exactly as typed but normalised (whitespace collapsed). Property: `parseLine(serializeLine(parseLine(s)))` deep-equals `parseLine(s)` (round-trip test over the whole Practice Card).

### 9.5 Card file format (bulk import / export / storage)

```
! Practice Card
!year 2026
# Year
FF 2026/x 2222/y 6666/y ; 25 ; X ; Year Kongs
// comments start with two slashes
# 2468
...
```
- `! <name>`: card name (first one wins). `!year <n>`: optional year. `# <section>`: sets the current section for the following lines (default section "Hands"). Blank lines are ignored.
- `parseCardFile(text)` → `{ card: Omit<Card,'id'|'createdAt'|'updatedAt'|'builtIn'>, errors: { lineNumber: number; text: string; errors: ParseError[] }[] }`. Valid lines are kept and invalid ones reported. Line IDs are **stable**: `L${index}_${hash(source)}` where hash = 32-bit FNV-1a in base36. This lets session records referencing a `lineId` survive re-parsing as long as the line is unchanged.
- `serializeCardFile(card)` emits the name, year, sections in order, and lines.

### 9.6 The built-in Practice Card (original; source of truth)

Put this verbatim in `src/domain/cards/practiceCard.ts` as `PRACTICE_CARD_TEXT` and parse it at module load into `PRACTICE_CARD: Card` (id `practice-v1`, `builtIn: true`). A unit test asserts it parses with **zero errors** and has 37 lines. Every variant already totals 14 tiles (verified while writing this spec).

```
! Practice Card
!year 2026
# Year
FF 2026/x 2222/y 6666/y ; 25 ; X ; Year Kongs
2222/x 000 222/y 6666/z ; 25 ; X ; Soap Year
FF NEWS 2026/x 2026/y ; 50 ; C ; Compass Year
2026/x 2026/y 2026/z DD/x ; 75 ; C ; Triple Year
# 2468
222/x 4444/x 666/x 8888/x ; 25 ; X ; Even Climb
FF 2222/x 44/y 66/y 8888/x ; 25 ; X ; Even Bookends
22/x 444/x 66/y 888/y DDDD/z ; 30 ; X ; Even Dragons
FFFF 2468/x 222/y 888/z ; 25 ; X ; Even Spread
FF 22/x 44/x 66/x 88/x 2468/y ; 50 ; C ; Even Pairs
# Like Numbers
FF 1111/x 11/y 1111/z DD/x ; 25 ; X ; Like Sandwich ; shift
1111/x 1111/y 111/z FFF ; 25 ; X ; Like Trio ; shift
FF 11/x 11/y 11/z DD/x DD/y DD/z ; 50 ; C ; Like Pairs ; shift
# Addition
FF 3333/x + 4444/y = 7777/z ; 25 ; X ; Three Plus Four
FF 1111/x + 5555/x = 6666/x ; 30 ; X ; One Plus Five
22/x + 55/x = 77/x 22/y + 55/y = 77/y FF ; 50 ; C ; Double Sum
# Quints
FFFF 11111/x 22222/y ; 45 ; X ; Quint Steps ; shift
NNNNN EEEE 11111/x | SSSSS WWWW 11111/x ; 40 ; X ; Wind Quints ; shift
11111/x DDDD/x 11111/y ; 45 ; X ; Like Quints ; shift
# Consecutive Run
11/x 222/x 3333/x 444/x 55/x ; 25 ; X ; Five Step Run ; shift
FFF 1111/x 2222/y 333/z ; 25 ; X ; Three Suit Run ; shift
111/x 2222/x 333/y 4444/y ; 25 ; X ; Two Suit Run ; shift
FF 1/x 22/x 333/x 4444/x 55/x ; 30 ; X ; Staircase ; shift
112233/x 445566/y FF ; 50 ; C ; Pair Ladder ; shift
# 13579
11/x 333/x 5555/x 777/x 99/x ; 25 ; X ; Odd Climb
FFFF 1111/x 9999/y 55/z ; 25 ; X ; Odd Ends
111/x 33/x 555/y 77/y 9999/z ; 30 ; X ; Odd Spread
13579/x 13579/y FFFF ; 40 ; C ; Odd Singles
11/x 33/x 55/x 77/x 99/x 11/y 99/y ; 50 ; C ; Odd Pairs
# Winds & Dragons
NNNN EEE WWW SSSS ; 25 ; X ; Four Winds
FF RRR GGG 000 NNN | FF RRR GGG 000 EEE | FF RRR GGG 000 WWW | FF RRR GGG 000 SSS ; 30 ; X ; Dragons And A Wind
NNN SSS DDDD/x DDDD/y ; 25 ; X ; North South Dragons
NEWS RR GG 00 FFFF ; 35 ; C ; Compass Dragons
# 369
333/x 666/x 9999/x DDDD/x ; 25 ; X ; Threes In One
FF 3333/x 6666/y 9999/z ; 25 ; X ; Threes Across
FF 33/x 66/x 99/x 33/y 66/y 99/y ; 50 ; C ; Threes In Pairs
# Singles & Pairs
NN EE WW SS 11/x 11/y 11/z ; 50 ; C ; Winds And Likes ; shift
FF 11/x 22/x 33/x 44/x 55/x 66/x ; 50 ; C ; Pair Run ; shift
```

### 9.7 Plain-English description (`describe.ts`)

`describeVariant(v, shift)` → e.g. for `FF 2026/x 2222/y 6666/y` (shift 0):
"Pair of Flowers · 2026 in suit A (0 is Soap) · Kong of 2s in suit B · Kong of 6s in suit B · A and B are different suits."
Rules: group names Single/Pair/Pung/Kong/Quint/Sextet; suit vars shown to users as **A/B/C** (x→A, y→B, z→C) with the colours from §11.2; fixed suits shown as Cracks/Bams/Dots; consecutive singles in one body are read as a run ("2026 in suit A", "1 3 5 7 9 in suit A"); `D/x` → "Kong of Dragons matching suit A"; shift 1 → append "Numbers can be any consecutive/like set (example shown)"; shift 2 → "… keeping odd/even". Concealed → "Concealed — only the last tile may be called".

---

## 10. Engine & scoring algorithms

### 10.1 Expansion: `expandLine(line): Target[]`

```ts
export interface TargetGroup { key: TileKey; count: number; jokerOk: boolean; gi: number /*group index in variant*/ }
export interface Target {
  lineId: string; variantIndex: number;
  binding: { x?: NumberSuit; y?: NumberSuit; z?: NumberSuit; k: number };
  groups: TargetGroup[];
  plainNeed: TileCounts;      // sum of counts of groups with count < 3, per key
  jokerNeed: TileCounts;      // sum of counts of groups with count >= 3, per key
  hasJokerGroups: boolean;    // any group count >= 3
  signature: string;          // canonical multiset string for dedupe, e.g. sorted "key:count:j" list
}
```
Algorithm per variant:
1. Collect the variables used (`x`,`y`,`z` subset) and the fixed suits used.
2. Enumerate **injective** assignments of the variables to `{C,B,D} \ fixedSuitsUsed` (≤ 6 assignments).
3. Enumerate `k` values: if `shift = 0` → `[0]`; else every integer `k` (multiple of 2 if `shift2`) such that `min(digits)+k ≥ 1` and `max(digits)+k ≤ 9`, where `digits` = all 1–9 digits across **all variants** of the line (so variants shift together).
4. Resolve each group: num → `numberKey(value+k, suit)`; dragon → `dragonFor(suit)`; fixed → its key. `jokerOk = count >= 3`.
5. Build `plainNeed`/`jokerNeed`, and skip targets violating copies (plain > copies, or total > copies + 8).
6. Dedupe within a line by `signature` (e.g. `x↔y` swaps in symmetric patterns give the same multiset).

`expandCard(card): Target[]`: memoise by `card.id + card.updatedAt`. The Practice Card expands to a few hundred targets; that's fine.

### 10.2 Player view and evaluation: `evaluate(target, view, live?)`

```ts
export interface Exposure { tiles: TileKey[] }            // e.g. ['5D','5D','J'] – naturals + jokers; all naturals identical
export interface PlayerView { rack: TileKey[]; exposures: Exposure[] }
export interface Evaluation {
  target: Target; lineId: string;
  possible: boolean;
  impossibleReason?: 'concealed' | 'exposure' | 'dead';
  distance: number;           // tiles still needed (0 = Mahjong). Counts against 14.
  missing: { key: TileKey; count: number; jokerOk: boolean }[]; // what to collect (natural tiles; jokerOk ones can also be jokers)
  usedRack: TileCounts;       // rack tiles that contribute (incl. 'J')
  unusedRack: TileKey[];      // rack tiles not contributing, sorted
  jokersUsed: number;
  jokerlessPossible: boolean; // distance computed with 0 jokers is finite (i.e. no exposure contains a joker)
  deadKeys: TileKey[];        // keys whose plain deficit exceeds live copies
  liveOuts: number;           // sum of live copies of keys still missing (+ live jokers if any jokerOk deficit)
}
```
Algorithm:
1. **Exposure normalisation:** for each exposure, its natural key = the single non-`J` key (an all-joker exposure is invalid input; the UI prevents it). `count = tiles.length`, `jokers = #J`.
2. **Concealed:** if `line.concealed` and `exposures.length > 0` → `possible=false, reason='concealed'`.
3. **Match exposures to groups:** for each exposure, find an unused target group with `key === natural && count === exposure.count && jokerOk`. If none → `possible=false, reason='exposure'`. Matched groups are complete.
4. For remaining groups, aggregate `plain[key]` and `jok[key]`. Let `have[key]` = rack counts, `J` = rack jokers.
5. Per key: `usePlain = min(have, plain)`; `rem = have - usePlain`; `useJ = min(rem, jok)`; `defPlain = plain - usePlain`; `defJ = jok - useJ`.
6. `D = Σ defJ`; `jokersUsed = min(J, D)`; `distance = Σ defPlain + (D - jokersUsed)`.
7. `missing`: per key with `defPlain>0` → `{key, count: defPlain, jokerOk:false}`. For jokerable deficits, the shortfall after jokers is allocated across keys in **ascending live-count order** (fill the hardest keys with jokers first) → `{key, count, jokerOk:true}`.
8. `usedRack` / `unusedRack` follow from steps 5–6 (unused jokers count as used? **No**: unused jokers go to `unusedRack`, but they are never suggested as passes or discards).
9. **Live/dead** (if a `live` map is provided, see 10.3): `deadKeys` = keys where `defPlain > live[key]`. Also mark dead if the post-joker jokerable shortfall `> Σ_k min(defJ_k, live[k]) + live['J']`. Dead → `possible=false, reason='dead'` (the distance is still reported).
10. `jokerlessPossible`: no exposure contains `J`, and the hand could be completed without jokers (not dead under live counts for naturals only, ignoring jokers). Simplified, which is acceptable: `!exposures.some(hasJoker) && no key needs more naturals than live`.

**Correctness:** assigning naturals to plain needs first is optimal, because jokers can fill only jokerable needs. Unit-test that against a brute-force solver on random small cases (property test with a fixed seed, 500 cases).

### 10.3 Live tiles: `liveCounts(view, seen): TileCounts`

`live[key] = TILE_COPIES[key] − rack[key] − exposureNaturals[key] − seen[key]`, floored at 0. `seen` = the user-entered counts of tiles visible elsewhere (discards + opponents' exposures). For `J`, rack/exposure jokers and seen jokers are subtracted the same way.

### 10.4 Ranking: `analyze(card, view, seen?) → LineResult[]`

```ts
export interface LineResult { line: CardLine; best: Evaluation; alternatives: number /* other possible targets for this line */ }
```
- Evaluate every target, then keep the best evaluation per line with this comparator: possible first → lower distance → fewer plain deficits (Σ defPlain) → higher liveOuts → higher points → card order.
- Sort the lines with the same comparator. Return all lines; the UI shows the top N.
- **Expose this as a single memoised function** keyed by (card id/updatedAt, sorted rack, exposures, seen), so React re-renders are cheap.

### 10.5 Suggestions (`suggest.ts`)

**Weights:** take the top `K = 6` possible lines from `analyze`, with `minD` = best distance. Weight `w = 1 / 2^(distance − minD)`, ×0.5 if the line is concealed and the user has exposures (shouldn't happen, but be safe).

**`suggestPasses(card, view, n = 3): PassSuggestion[]`** (Charleston; `view.exposures` empty)
- Treat each non-joker rack tile **instance** separately: if the rack has two `7B` and a top line uses one, one instance gets that line's weight and the other gets 0.
- `utility(instance) = Σ w_i` over the top lines whose `usedRack` includes it.
- Pick the `n` lowest-utility instances. Ties: lower **card coverage** first (coverage = number of lines in the whole card with any target containing that key; precompute per card), then singletons before pairs, then `TILE_KEYS` order (deterministic).
- **Never** suggest `J` (jokers may not be passed).
- `reason` strings (exact templates):
  - utility 0 and coverage 0: `"No hand on this card uses it"`
  - utility 0: `"Not used by your top hands"`
  - otherwise: `"Only helps {lineName} ({distance} away)"` naming the highest-weight line that uses it (`lineName` = name ?? `section` + " #" + index).
- Also return `focus: { section: string; lines: string[] }[]`: the top 2–3 *sections* by summed weight. The coach shows: "Keep options open: you're strongest in **2468** and **Like Numbers**."

**`suggestDiscards(card, view, seen?, danger?): DiscardSuggestion[]`** (Playing; rack + exposure tiles total 14)
- For each distinct non-`J` key in the rack: remove one copy, compute `analyze` → `bestDistance`, plus `utility` as above (computed on the original view).
- Sort by bestDistance asc → utility asc → danger asc (from Scout, 0..1, default 0) → `TILE_KEYS` order. Return the top 3.
- Reason: `"Keeps you {d} away on {lineName}"`, appending `" · risky: an opponent may need it"` if danger ≥ 0.5.

**`checkCall(card, view, tile): CallVerdict[]`**
- For each top-10 possible line (best target): let `view' = rack + tile`.
  - If `evaluate(target, view').distance === 0` → verdict `{kind:'mahjong', line}` ("Call it — that's Mahjong!"). This is allowed for X or C lines and for any group size.
  - Else if the line is not concealed: find a remaining group `g` with `g.key === tile && g.jokerOk` where `rack[tile] + spareJokers ≥ g.count − 1` (`spareJokers` = rack jokers not needed elsewhere, i.e. `J − jokersUsed` from the current evaluation, plus jokers already counted toward this same group). Verdict `{kind:'expose', line, groupSize: g.count, newDistance}` where `newDistance` = the distance after adding the tile and moving that group into exposures.
- Sort: mahjong first, then the smallest newDistance. An empty result → UI: "Let it go — it doesn't help your top hands."

### 10.6 Scout: `scoutOpponents(card, opponents: Exposure[][], seen?)`

- For each opponent with ≥1 exposure: a line is **consistent** if it is not concealed and some target can match all their exposures (step 3 of 10.2).
- For each consistent line, take the target(s) that match and collect their **remaining keys** (keys of unmatched groups).
- `danger[key] = Σ_targets (1 / #consistentTargetsForThatOpponent)`, then take the max across opponents and normalise to 0..1.
- Return `{ perOpponent: { label, lines: CardLine[] }[], danger: TileCounts (0..1 floats), safe: TileKey[] /* keys with danger 0, excluding J */ }`.
- With no exposures entered → return empty, and the UI says "Add what they've exposed to see what they might be going for."

### 10.7 Payouts: `computePayments(session, input, rules): Record<playerId, number>`

Let `P` = basePoints, `jl` = `input.jokerless && (input.lineHasNoJokerGroups ? rules.jokerlessBonusForNoJokerLines : true)`, `J = jl ? rules.jokerlessMultiplier : 1`. The players are the session's `seatIds`.
- **Discard** (`discarderId` set): the discarder pays `P × discarderMultiplier × J`; each other non-winner pays `P × othersOnDiscardMultiplier × J`.
- **Self-pick**: each non-winner pays `P × selfPickMultiplier × J`.
- The winner receives the sum, so the result is zero-sum.
- **Wall:** `kind 'none'` → all zeros. `everyonePaysWinnerless` is reserved and should not be exposed in the UI for v1. (Keep the type so a house-rule toggle can be added later.)
- **Adjustment:** `from −points`, `to +points`.

**Required tests** (STANDARD_RULES; players A,B,C,D; A wins with 25):
| Case | A | B | C | D |
|---|---|---|---|---|
| B discards | +100 | −50 | −25 | −25 |
| Self-pick | +150 | −50 | −50 | −50 |
| B discards, jokerless | +200 | −100 | −50 | −50 |
| Self-pick, jokerless | +300 | −100 | −100 | −100 |
| B discards, jokerless, line has no joker groups (bonus off) | +100 | −50 | −25 | −25 |
| 3 players A,B,C; B discards | +75 | −50 | −25 | — |

**Money:** `cents = points × centsPerPoint`. Format with the currency symbol, e.g. `$1.25`, `−$0.50`.

### 10.8 Session reducers (`session.ts`, pure)

- `currentDealerId(session)`: `seatIds[(startDealerIndex + countOf(hands where kind ∈ {mahjong, wall})) % seatIds.length]`.
- `addHand(session, input, now, id)`, `editHand(session, handId, input)` (recomputes payments with `session.rules`), `removeHand(session, handId)`, `undoLast(session)`, `setRules(session, rules)` (recomputes **all** hands), `endSession(session, now)`.
- `totals(session): Record<playerId, number>` (points); `moneyTotals` (cents).
- `settleUp(totalsCents): {fromId, toId, cents}[]`: greedy. Repeatedly match the largest debtor with the largest creditor, transferring the minimum of the two. Output sorted by amount desc. Property test: transfers net to the totals, and the count ≤ players − 1.

### 10.9 Stats (`stats.ts`)

`playerStats(playerId, sessions)` → `{ sessionsPlayed, handsPlayed (mahjong+wall while seated), wins, winRate, selfPicks, jokerlessWins, avgWinPoints, biggestWin {points, lineLabel, date}, timesDiscardedWinner, netPoints, netCents, favoriteLines: {label, count}[] (top 3), sessionWins (sessions where they finished top) }`.
`lineStats(cardId, sessions)` → wins per lineId (shown on Line detail as "You've won this 3 times").

---

## 11. UX / UI specification

### 11.1 Information architecture

Tabs (Ionicons, outline when inactive, filled when active):
1. **Game** (`dice-outline`/`dice`): scorekeeper. Default tab.
2. **Helper** (`bulb-outline`/`bulb`): hidden when Assist Level = Off. (Use `href: null` on the tab when hidden. Settings still allows turning it back on.)
3. **Cards** (`albums-outline`/`albums`)
4. **Learn** (`school-outline`/`school`)

The settings gear (`settings-outline`) sits in the header right of every tab's root screen and opens `/settings` as a modal.

### 11.2 Design tokens (`src/ui/theme/tokens.ts`)

```ts
light = {
  bg: '#F7F3EA',  surface: '#FFFFFF', surfaceAlt: '#EFE8D8', border: '#E1D8C4',
  text: '#1E2420', textMuted: '#5E665F', textFaint: '#8C928A',
  primary: '#1F6B52', onPrimary: '#FFFFFF', primarySoft: '#DCEBE4',
  accent: '#C8423B', gold: '#B8862A', success: '#2E7D4F', warning: '#B7791F', danger: '#B3261E',
  tileFace: '#FFFDF7', tileEdge: '#1F6B52', tileShadow: 'rgba(30,36,32,0.18)',
  suitC: '#C8423B', suitB: '#2E7D4F', suitD: '#2F5D9E',
  varA: '#2F5D9E', varB: '#C8423B', varC: '#2E7D4F',   // card-style colours for suit variables x/y/z
  flower: '#8A4FA3', joker: '#B8862A',
}
dark = {
  bg: '#121614', surface: '#1B201D', surfaceAlt: '#242A26', border: '#2F3631',
  text: '#ECE7DC', textMuted: '#A3A99F', textFaint: '#737A72',
  primary: '#4FB38C', onPrimary: '#0E1411', primarySoft: '#1F3A2F',
  accent: '#E2675F', gold: '#E0B451', success: '#5BBF86', warning: '#E0A84F', danger: '#F2766D',
  tileFace: '#F4EFE3', tileEdge: '#2E8A69', tileShadow: 'rgba(0,0,0,0.5)',
  suitC: '#C8423B', suitB: '#2E7D4F', suitD: '#2F5D9E',   // tile faces stay ivory in dark mode, so suit inks stay the same
  varA: '#7FA6E0', varB: '#E2675F', varC: '#5BBF86',
  flower: '#8A4FA3', joker: '#B8862A',
}
spacing = { xs: 4, sm: 8, md: 12, lg: 16, xl: 24, xxl: 32 }
radius  = { sm: 6, md: 10, lg: 16, pill: 999 }
type    = { title: 28/34 bold (Fraunces 600 if loaded, else system bold), h2: 20/26 semibold, body: 16/22, small: 13/18, tiny: 11/14 semibold uppercase tracking 0.6 }
```
`ThemeProvider` resolves `settings.theme` + `useColorScheme()`. Set `app.json` `userInterfaceStyle: "automatic"`.

### 11.3 Assist levels (behaviour matrix)

| Surface | Off | Peek | Coach |
|---|---|---|---|
| Helper tab | hidden | visible | visible |
| Closest hands list | — | collapsed behind **"Show closest hands"**; top 3 | always open; top 8 + "Show all" |
| Missing tiles per hand | — | on tap of a hand | shown inline |
| Pass/discard suggestions | — | behind **"Suggest a pass/discard"** button | shown automatically with reasons |
| Can I call it? | — | available | available + explanation |
| Scout danger tiles | — | available | available + "why" per tile |
| Tips (one per screen, §12.3) | — | — | shown, dismissible |
| Record-hand payment explanation | 1-line | 1-line | full sentence breakdown |

The Helper header has an Assist chip (e.g. "Peek ▾") that changes the global setting.

### 11.4 Core components (in `src/ui/components`)

- `Screen` (safe area + bg + optional scroll + maxWidth 640), `ScreenHeader` (title, right actions).
- `Button` (variants: primary / secondary / ghost / danger; sizes md / lg; `lg` is 56 tall for table use), `IconButton`.
- `Card` (surface, radius lg, border), `ListRow` (title, subtitle, right accessory, chevron).
- `Chip` (selectable; used for players, quick points), `Segmented` (2–4 options), `Toggle` (labelled Switch), `Stepper` (−/+ with value; step configurable).
- `Sheet` (bottom-sheet-style modal using a RN `Modal` with a slide animation; drag handle; used for the exposure picker and the call checker).
- `Avatar` (initials on a player colour circle), `Badge` (X/C, Dead, East, Jokerless), `EmptyState` (icon, title, body, action).
- `PointsText` (+green/−red with sign), `MoneyText`.
- `Tile`, `TileRack`, `TileKeyboard`, `HandPattern` (below).

### 11.5 Tiles

**`<Tile k size="sm|md|lg" state="normal|dim|selected|missing" onPress?>`**
- Sizes (w×h): sm 28×38, md 40×54, lg 52×70. Radius 6/8/10. Face `tileFace`. 3px bottom border `tileEdge` (the tile's coloured back), plus a subtle shadow.
- Faces (SVG/Text, centered):
  - Number tiles: large numeral (bold, colour by suit) on top, with a suit glyph below: **Cracks** = the character 萬 in `suitC`; **Bams** = a small SVG bamboo stalk (two segments) in `suitB`; **Dots** = an SVG ring (circle with inner dot) in `suitD`.
  - Winds: big letter N/E/S/W in `text` dark ink, with a tiny arrow glyph.
  - Dragons: `R` = 中 in `suitC`; `G` = 發 in `suitB`; `0` (Soap) = an SVG rounded rectangle frame in `suitD` with "0" small beneath.
  - Flower: SVG 5-petal flower in `flower`.
  - Joker: "JOKER" vertical/condensed in `joker` with a star.
- `dim`: 40% opacity. `selected`: 2px `primary` ring + lift. `missing`: dashed `border` outline, no face, faint label (used in patterns for tiles still needed).
- `accessibilityLabel = tileName(k)`.

**`<TileKeyboard onAdd counts maxed>`**: 4 rows: Cracks 1–9, Bams 1–9, Dots 1–9, then `N E W S R G 0 F J`. Uses size `sm` on phones < 380pt wide, `md` otherwise. Each key shows a small count badge if ≥1 is in use. A key is disabled once it reaches its physical copies (counting rack + exposures + seen in Playing mode). Haptic selection feedback on tap.

**`<TileRack tiles onRemove sort>`**: a horizontal wrap of `md` tiles with "12/14" counter, Sort toggle, and Clear (confirm if > 3 tiles). Tap a tile to remove it (with a quick shrink animation).

### 11.6 `<HandPattern variant line evaluation? showSuitLetters?>`

Renders a card line like the printed card: each group as a cluster of glyph text, with spacing between groups and `+`/`=` ops shown as plain text.
- **Compact mode** (lists): monospace-ish bold text per group, e.g. `FF 2026 2222 6666`, each group coloured by its suit variable (`varA/B/C`), fixed suits coloured by suit colour, honors in `text`, flowers in `flower`. With `showSuitLetters`, add a subscript `A`/`B`/`C`.
- **Tile mode** (Line detail, Helper results expanded): actual `Tile` components `sm` for the **resolved best target** (concrete suits). Tiles the player has are `normal`, tiles still needed are `missing`, and joker-filled tiles show as a `J` tile with a small dot. Groups are separated by 8px gaps.
- Below: "N away · 25 pts · X" row and, if missing, "Need: [tiles]".

### 11.7 Screens

Each screen below lists its **layout top→bottom**, **states**, and **actions**.

**Game home (`/(tabs)/game`)**
- If an active session exists: a "Game in progress" card (players' avatars, hands played, leader) with **Resume** (primary). Below it, "Start a new game night" (secondary).
- Otherwise: hero `EmptyState`-like panel ("Ready for game night?", primary **Start game night**).
- Sections: **Recent** (last 5 sessions: date, avatars, winner, `ListRow` → session read-only), links **All history**, **Players & stats**.

**Session setup (`/game/new`)**
- Step list on one scroll: **Players** (chips of roster players; tap to toggle; "+ Add player" inline text field + colour; must pick 3–4; selection order = seat order) → **Seats** (ordered list with ↑↓ buttons; tap "Make East" on a row, default first) → **Card** (dropdown: None / Practice Card / user cards; default = settings.activeCardId) → **Rules** (row "Standard rules ›" opens rules editor; shows a summary like "Discarder ×2 · Self-pick ×2 · Jokerless ×2") → **Money** (Toggle + ¢/point stepper, default from settings).
- A sticky bottom **Start** button (disabled until 3–4 players are selected).

**Scoreboard (`/game/[sessionId]`)**
- Header: "Game night · Oct 8", with an overflow menu (Undo last, Adjustment, Rules, End game night).
- Scoreboard grid: one row per seat: Avatar, name, an "EAST" badge on the current dealer, net points (`PointsText`, large), and net money below if enabled. The leader gets a subtle gold crown.
- Primary `Button lg` **Record a hand**, secondary **Wall game**.
- **Hand log:** newest first. Row: `#n`, winner avatar + "Bea — Even Climb" (or "25 pts"), meta "self-pick · jokerless" / "from Cy", the winner's +points. Tap → edit (record screen with handId). Swipe or long-press → delete (confirm).
- Empty log: "No hands yet. Shuffle up!".
- Keep-awake active while focused (if setting on).

**Record hand (`/game/[sessionId]/record`, modal)**
- Sections on one screen (no wizard pages, so experienced users can tap straight through):
  1. **Who won?** player chips (big, avatar + name).
  2. **How?** Segmented [Self-pick | Discard]. If Discard → "Who threw it?" chips (excluding the winner).
  3. **Hand:** if the session has a card → searchable line picker (button "Choose hand ›" opens a list grouped by section with the compact pattern + points; selecting sets the points). Always available: **Points** quick chips + Stepper (step 5). Selecting a line fills points; editing points afterwards keeps the line label but marks "custom value".
  4. **Jokerless?** Toggle (disabled with the note "Singles & Pairs hands are already jokerless — no bonus" when the line has no joker groups and the rule is off).
  5. **Note** (optional, collapsed "+ Add note").
  6. **Preview card:** each player `PointsText` (+ money), plus an explanation (per assist level: Off/Peek → "Cy pays 50 (threw it) · others pay 25"; Coach → "Base 25. Cy threw the winning tile, so Cy pays double (50). Everyone else pays the base (25). Bea collects 100.").
- Save (primary, disabled until winner + how (+ discarder) + points > 0). Haptic success on save, then dismiss.

**Summary (`/game/[sessionId]/summary`)** (shown after End game night; also reachable from history)
- Podium/standings list; highlights (Biggest hand, Most wins, Most jokerless); **Settle up** list; **Share** button (text: title, date, standings, settle-up lines, "Kept with Mahjong Mania").

**History (`/game/history`)**: sessions grouped by month; tap → scoreboard (read-only if ended; a "Reopen" action in the menu).

**Players (`/game/players`)**: roster list with Avatar, name, wins, and net. "+ Add". Tap → **Player stats** (§10.9 metrics as stat tiles; favourite hands list; rename / change colour / archive).

**Helper (`/(tabs)/helper`)**
- Header row: Card chip ("Practice Card ▾" → picker sheet), Assist chip.
- Segmented: Charleston | Playing | Scout.
- **Charleston/Playing:**
  - `TileRack` (my concealed tiles). In Playing mode, an "Exposures" row below it: existing exposures as tile groups + "+ Exposure" → Sheet: pick a tile, choose size 3/4/5/6, choose how many jokers (0..size−1), Add.
  - In Playing mode, a "Seen tiles" collapsible: a compact keyboard where each tap increments a seen count (long-press decrements). Shows "14 seen".
  - `TileKeyboard` docked at the bottom (collapsible with a handle to give the results more room; it auto-collapses when the rack is full (13/14) and expands again on tapping the rack).
  - Results area (scroll): assist-gated "Closest hands" list of `ResultCard` (compact `HandPattern`, "3 away", points, badges; tap to expand into tile mode with missing tiles). Pinned line (from "Practise this hand") shown first with a pin icon.
  - Coach panel (per §11.3): Charleston → "Pass these" (3 tiles, `Tile md`, reasons) + focus sentence; Playing → "Discard" suggestions + **Can I call it?** button → Sheet with the keyboard ("Which tile was discarded?") → verdict list.
  - Empty state (no tiles): "Add your tiles to see which hands you're closest to." with a "Deal me a random hand" ghost button (useful for learning).
- **Scout:** a list of opponents (default "Right", "Across", "Left"), each with an exposures row and "+ Exposure". Below: **Danger tiles** (tiles sorted by danger with a heat bar, red → amber) and **Safer tiles**; per opponent "Could be going for:" up to 5 line names (tap → line detail).

**Cards list (`/(tabs)/cards`)**: `ListRow`s: Practice Card (badge "Built-in"), user cards; the active one has a check. Header actions: **New** (→ name prompt → empty card detail), **Import**. Row long-press menu: Set active, Duplicate, Rename, Share, Delete.

**Card detail (`/cards/[cardId]`)**: search field; SectionList of lines: compact `HandPattern` + name + points + X/C badge. For user cards: "+ Add hand" FAB → editor; swipe row → edit/delete; "Share card" in the header menu. For built-in: a banner "Built-in card · Duplicate to edit".

**Line detail (`/cards/[cardId]/line/[lineId]`)**: big tile-mode pattern of the first target (suits A=Dots, B=Cracks, C=Bams by default; a "Try other suits" control cycles bindings; the shift stepper changes the example numbers for shift lines). Description text (§9.7). Variants list. Stats ("You've won this 2×"). Buttons: **Practise this hand** (→ Helper with pinned line), Edit (user cards).

**Line editor (`/cards/[cardId]/edit`)**
- Fields: Section (picker of existing + "New section…"), Name, Notation (multiline TextInput, monospace, `autoCapitalize="characters"` **off**, autocorrect off), and a **key row** above the keyboard (horizontal scroll) with insert buttons `F N E W S R G 0 D 1–9 /x /y /z /c /b /d | + =` plus space and backspace. Points (Stepper + quick chips), Exposed/Concealed segmented, Shift segmented (None / Consecutive / Odd-even).
- Live area: parse errors (red, with a caret marker at `start`), else tile-mode preview + description + "14 tiles ✓".
- Save is disabled while errors exist. A one-time copyright notice banner (`cardNoticeSeen`).

**Import (`/cards/import`)**: a large text area ("Paste a card file"), a destination radio (New card / Add to existing ▾), a **Check** button → results list (✓ count, each error with its line number and message). **Import N hands** enabled when N > 0. A link to the notation guide.

**Learn home (`/(tabs)/learn`)**: cards for Rules quick reference, Tiles, Reading a card, Notation, Glossary; and Drills: Pick-a-Hand, Charleston Pass (with best streaks).

**Learn topic (`/learn/[topic]`)**: renders content from `src/content/*.ts` (structured as `{ title, sections: { heading, body: string[] | ExampleBlock }[] }`, where `ExampleBlock = { notation: string }` is rendered with `HandPattern`). Simple prose, short paragraphs, bulleted lists.

**Drill: Pick-a-Hand**: deal 13 tiles (seeded; the seed is shown small for "replay"). The user scrolls the card's lines and taps one ("I'd go for this") → reveal: top 3 lines with distances, whether their pick was in the top 3 (✓ streak +1) or not (streak reset), and a coach explanation ("You hold 3 pairs of evens, so 2468 lines are 6 away…"). Buttons: Next deal, Try again (same seed).

**Drill: Charleston Pass**: deal 13; the user selects exactly 3 tiles (jokers can't be selected: shake + toast "Jokers can't be passed"), then Submit → compare with `suggestPasses`: score = number of the user's tiles whose utility ≤ the max utility in the engine's set (so "equally good" picks count). Show both sets and the reasons.

**Onboarding**: 3 full-screen pages with the progress dots, Skip, and Next. Page 2 sets `assistLevel`. Page 3 sets `activeCardId` or routes to Cards → New after finishing.

**Settings**: grouped list per §4.5. "Reset all data" clears all stores, then shows onboarding again.

### 11.8 Motion, haptics, feel

- Tile add: scale 0.8→1 (120ms). Remove: scale→0.6 + fade (100ms). Results list reorder: `LinearTransition` from reanimated (`layout` prop) with a 200ms duration.
- Haptics: `selectionAsync` on keyboard taps, `impactAsync(Light)` on chip select, `notificationAsync(Success)` on save, Warning on validation error. All gated by `settings.haptics`.
- No confetti, except a single tasteful gold flash on the scoreboard row of the winner after saving.

---

## 12. Content

### 12.1 Rules quick reference (`content/rules.ts`): sections and facts to cover (write in your own words)

1. **The goal:** first to make 14 tiles matching a line on the card calls "Mahjong".
2. **The tiles:** the table from §5.1 in friendly words; Soap; flowers; jokers.
3. **The card:** lines are grouped into families; colours mean suits (same colour = same suit, different colours = different suits); X/C; points.
4. **Setup & the deal:** East has 14 tiles, others 13. East discards first and play moves to the right.
5. **The Charleston:** §5.3 steps as a numbered list with arrows; blind pass; courtesy pass; the stop option; never pass jokers.
6. **Your turn:** draw → (optional joker exchange) → discard, naming the tile aloud.
7. **Calling:** for pung/kong/quint or for Mahjong; you must expose the group; singles/pairs only for Mahjong; Mahjong beats an exposure call; ties go to the player next in turn.
8. **Jokers:** groups of 3+ only; joker exchange.
9. **Winning & paying:** discard vs self-pick vs jokerless (with the 25-point worked table from §10.7).
10. **Dead hands & wall games.**
11. A closing note: *"Your card's printed rules and your table's house rules always win."*

### 12.2 Glossary (`content/glossary.ts`): minimum entries

Bam, Crak, Dot, Soap, Flower, Joker, Wind, Dragon, Matching dragon, Single, Pair, Pung, Kong, Quint, Sextet, Exposure, Concealed (C), Exposed (X), Charleston, Blind pass, Courtesy pass, Rack, Wall, East/Dealer, Self-pick, Jokerless, Dead hand, Wall game, Joker exchange (redeeming), Calling, Mahjong, Family/Section, Like numbers, Consecutive run, Singles & Pairs, Hot tile (a tile likely to complete an opponent's hand).

### 12.3 Coach tips (`content/tips.ts`), shown one at a time in Coach mode (rotating, dismissible, never repeated within a session)

Examples to include (write ~15):
- "Early on, keep 2–3 hands in mind. Commit after the Charleston."
- "Pairs are hard to finish: jokers can't help with them. Favour hands where your pairs are already done."
- "Singles & Pairs hands must be decided early: no jokers, no calling."
- "A tile that 3 people have already discarded is probably safe to throw."
- "Watch exposures. If someone has a kong of 6 Dots, don't hand them 6 Dots."
- "Jokers are gold. You can't pass them, and you should almost never discard them."

---

## 13. Implementation plan (one PR per phase)

General rules for every phase:
- Branch from latest `main`. Keep the PR focused on the phase. The PR description lists the acceptance boxes, ticked.
- Run `npm run check` locally before pushing. CI (from Phase 0) must be green before merging.
- Where a UI screen is added, verify it renders on web (`npx expo start --web`, or `npx expo export -p web` + serve) and attach a screenshot (Playwright is available in the agent sandbox; use executablePath `/opt/pw-browsers/chromium` if needed). Web is only a dev preview. Don't add web-specific code beyond what's needed to render.

### Phase 0: Reset & foundation
**Tasks**
- [ ] Delete `app/`, `src/`, `App.tsx`, `index.ts`, `README.md.bak`.
- [ ] `package.json`: `"name": "mahjong-mania"`, `"main": "expo-router/entry"`, scripts:
  `start`, `ios`, `android`, `web`, `typecheck: tsc --noEmit`, `lint: expo lint`, `test: jest`, `format: prettier --write .`, `check: npm run typecheck && npm run lint && npm run test -- --ci`.
- [ ] `npx expo install` the packages in §6.2. `npm i zustand`, `npm i -D @testing-library/react-native prettier` (+ eslint if `expo lint` asks).
- [ ] `app.json`: name "Mahjong Mania", slug `mahjong-mania`, scheme `mahjongmania`, `userInterfaceStyle: "automatic"`, `plugins: ["expo-router", "expo-sqlite", "expo-font"]` (only those that have config plugins and are installed), `experiments.typedRoutes: true`, splash background `#F7F3EA`, `ios.bundleIdentifier` / `android.package` = `com.joshbelot.mahjongmania`.
- [ ] `tsconfig.json`: strict, `paths: { "@/*": ["./src/*"] }`, include `.expo/types/**/*.ts`, `expo-env.d.ts`.
- [ ] Jest: `jest.config.js` with `preset: 'jest-expo'`, `setupFiles` → `src/test/setup.ts` (mock `expo-sqlite/kv-store` with an in-memory Map implementing `getItem`/`setItem`/`removeItem` + their `*Sync` variants if used), `moduleNameMapper` for `@/`.
- [ ] ESLint flat config via `npx expo lint` (generates `eslint.config.js`); `.prettierrc` `{ "singleQuote": true, "trailingComma": "all", "printWidth": 100 }`.
- [ ] `.github/workflows/ci.yml`: on PR + push to main; Node 22; `npm ci`; `npm run check`.
- [ ] `src/ui/theme/*` (tokens §11.2, ThemeProvider, useTheme) and a minimal `src/store/settings.ts` (theme only for now, persisted).
- [ ] Routes scaffold: root `_layout` (ThemeProvider, GestureHandlerRootView, SafeAreaProvider, splash hide after hydration), `(tabs)/_layout` with 4 tabs + Ionicons, each tab root a placeholder `Screen` with its title.
- [ ] Update `README.md`: what the app is, how to run, scripts, link to this spec.
**Acceptance**
- [ ] `npm run check` passes (include one trivial test so jest runs).
- [ ] `npx expo start --web` renders the 4 tabs with correct icons, light and dark themes.
- [ ] No leftover imports of deleted code.

### Phase 1: Tiles, random, wall
**Tasks:** implement `src/domain/tiles.ts` (§7), `random.ts` (`mulberry32(seed)`, `shuffle(arr, rng)`, `newId(prefix)`), `wall.ts` (`fullWall(): TileKey[]` of 152, `deal(seed, n=13): { hand: TileKey[]; rest: TileKey[] }`).
**Tests:** wall has 152 tiles with the correct copies per key; `sortTiles` order; `dragonFor`; `tileName` for every key; the same seed → the same deal; different seeds → different deals.
**Acceptance:** 100% statement coverage of these files.

### Phase 2: Notation (parse, serialize, describe) + Practice Card
**Tasks:** `notation/types.ts`, `parse.ts` (`parseLine(text, opts?: { id?: string; section?: string }) → { line?: CardLine; errors: ParseError[] }`, `parseCardFile`), `format.ts` (`serializeLine`, `serializeCardFile`), `describe.ts`, `cards/practiceCard.ts`.
**Tests (minimum):**
- Body splitting: `2222`→[4×2]; `2026/x`→[2,0,2,6]; `11222/x`→[2×1, 3×2]; `NEWS`→4 singles; `FFFF`→[4×F].
- Errors: `FF 2222 4444 6666 88 ; 25 ; X` → MISSING_SUIT at `2222`; `FF 2222/q …` → BAD_SUIT/BAD_CHAR; 13-tile line → TILE_COUNT with message containing "13"; `NNNNNNN…` → GROUP_TOO_BIG; `; 0 ; X` → BAD_POINTS; `; 25 ; Q` → BAD_EXPOSURE; `; 25 ; X ; name ; wobble` → BAD_FLAG; `shift` on `NNNN EEE WWW SSSS` → SHIFT_NO_NUMBERS.
- Variants with `|` each validated independently.
- Ops `+`, `=` are kept in tokens but not in groups.
- Practice Card parses with 0 errors, 37 lines, 10 sections in the given order.
- Round-trip property (§9.4) for every Practice Card line.
- `describeVariant` snapshot for 5 representative lines.
- `parseCardFile` reports errors with correct 1-based line numbers and still returns valid lines. Stable line IDs: re-parsing the same text yields the same IDs.

### Phase 3: Engine core (expand, evaluate, live, analyze)
**Tasks:** `engine/types.ts`, `expand.ts`, `evaluate.ts`, `live.ts`, `rank.ts`, `index.ts` (`createAnalyzer(card)` returning memoised `analyze(view, seen?)`).
**Tests (minimum):**
- Expansion counts: `Even Climb` (one var, no shift) → 3 targets; `Three Plus Four` (x,y,z) → 6; `Five Step Run` (shift, digits 1–5, one var) → k∈0..4 × 3 suits = 15; `Four Winds` → 1; `Dragons And A Wind` → 4 (variants); `Like Quints` (x,y + shift 0..8) → 6×9=54 before dedupe.
- Distinct suits enforced: no `Three Plus Four` target has two equal suits.
- Matching dragon: `Even Dragons` with z=C resolves `DDDD/z` to `R`.
- Evaluate: a perfect 14-tile rack → distance 0; the same rack minus one tile of a pair → distance 1, missing that tile with jokerOk false; a rack with 2 jokers covering a pung deficit → distance 0 and jokersUsed 2; jokers can't fill a pair (distance stays 1); exposure matching (correct exposure → ok; exposure of the wrong size → reason 'exposure'); concealed + exposure → reason 'concealed'.
- Live/dead: needing a pair of `N` when 3 `N` are seen and none in hand → dead.
- Brute-force property test (§10.2 correctness, 500 seeded random cases on small random targets).
- Ranking order follows the comparator. Ties broken by card order.
- Performance test (§8).

### Phase 4: Suggestions & scout
**Tasks:** `suggest.ts` (`suggestPasses`, `suggestDiscards`, `checkCall`), `scout.ts`, plus `coverage` precompute in `index.ts`.
**Tests:**
- `suggestPasses` never returns `J`; returns exactly n tiles; for a rack that is 1 tile from `Even Climb` plus 3 odd strays, it returns those strays with reason "Not used by your top hands" (or "No hand on this card uses it").
- Instance handling: with two `7B` where only one is used, exactly one `7B` can be suggested.
- `suggestDiscards`: on a 14-tile rack that's 1 away, the top suggestion keeps distance 1 and the stray tile is suggested first.
- `checkCall`: a tile completing Mahjong → mahjong verdict (also for concealed lines); a tile completing a pung when holding 2 → expose verdict with the correct newDistance; a pair tile (not Mahjong) → no expose verdict; a concealed line → no expose verdict.
- `scoutOpponents`: an opponent exposing a kong of `2C` is consistent only with lines that contain a kong-capable group that can resolve to 2C; danger is highest for keys in those lines' remaining groups; concealed lines are excluded.

### Phase 5: Scoring domain
**Tasks:** `scoring/types.ts`, `rules.ts` (`STANDARD_RULES` = 2/1/2/2, bonus-for-no-joker-lines false, wall none, money off 1¢ `$`), `payout.ts`, `session.ts`, `settle.ts`, `stats.ts`, `formatMoney(cents, symbol)`.
**Tests:** the full table in §10.7; zero-sum property over random inputs; dealer rotation (wall and mahjong advance it; adjustments don't); editHand recompute; setRules recompute; settleUp properties; stats on a fixture of 2 sessions (hand-computed expectations).

### Phase 6: Design system & tile components
**Tasks:** all components in §11.4, `Tile` faces (§11.5), `TileKeyboard`, `TileRack`, `HandPattern` (compact + tile mode). Add a hidden dev route `app/dev/components.tsx` (only registered when `__DEV__`) showing every component in light and dark: the "storybook".
**Tests:** RNTL render tests: `Tile` has the right accessibilityLabel for each key; `TileKeyboard` disables a key at max copies; `HandPattern` compact renders `FF 2026 2222 6666` groups with 4 text nodes; tile mode marks missing tiles.
**Acceptance:** screenshot of the dev route in both themes attached to the PR; all text contrast checked against tokens.

### Phase 7: Stores & persistence
**Tasks:** `store/storage.ts` (`export const kvStorage = createJSONStorage(() => Storage)`, importing `Storage` from `expo-sqlite/kv-store`), `settings.ts` (full shape §7), `players.ts`, `sessions.ts` (actions wrap the pure reducers from `session.ts`), `cards.ts` (user cards as text; selector `useCard(id)` returns the parsed Card (memoised), including built-in practice), `helper.ts`. A `useHydrated()` hook (all stores hydrated) for the splash gate.
**Tests:** each store's actions (with the kv mock), a migration stub test (version 1 → itself), and that the parsed-card memo returns the same object for an unchanged `updatedAt`.

### Phase 8: Cards feature
**Tasks:** Cards list, Card detail, Line detail, Line editor (with key row and live preview), Import, Share/export, Duplicate built-in, set active card. Copyright notice.
**Acceptance:**
- [ ] Can duplicate the Practice Card, edit a line, see the live errors, save, and see it in detail.
- [ ] Paste the Practice Card text into Import → "37 hands ✓" → import into a new card.
- [ ] Share produces the canonical card file text.
- [ ] RNTL tests: the editor disables Save on errors and shows the error message; Import shows a per-line error with its line number.

### Phase 9: Game Night feature
**Tasks:** Game home, Session setup, Scoreboard, Record hand (create/edit), Wall game, Adjustment sheet, Undo, Rules editor modal (edit multipliers with Steppers, jokerless-bonus toggle, money), End & Summary, History, Players list, Player stats. Keep-awake on the scoreboard.
**Acceptance:**
- [ ] A full game night of 6 hands can be recorded on web in the browser: the totals match the hand-computed values and settle-up is correct.
- [ ] Record-hand flow: an experienced path (winner → discard → thrower → 25 chip → Save) is 5 taps.
- [ ] Editing a hand updates the totals; undo works; the dealer badge rotates correctly.
- [ ] Data persists across reload.
- [ ] RNTL tests for the record-hand screen (Save disabled states, preview numbers) and the scoreboard totals.

### Phase 10: Hand Helper feature
**Tasks:** Helper screen with the 3 modes, rack/exposures/seen inputs, results list with expand, assist-level gating (§11.3), Coach panel (passes, discards, call checker sheet), Scout UI, "Deal me a random hand", pinned line from "Practise this hand", card & assist chips.
**Acceptance:**
- [ ] With a dealt rack, results update within one frame of a tile tap (no visible lag on web).
- [ ] Assist Off hides the tab. Peek requires a tap to reveal. Coach shows everything.
- [ ] The call checker gives the right verdict for the 3 scenarios from the Phase 4 tests, reproduced in the UI.
- [ ] RNTL tests for the gating matrix.

### Phase 11: Learn, drills, onboarding
**Tasks:** content files (§12), Learn home & topic renderer, Notation guide with live examples, Glossary (searchable), both drills with streaks (persist the best streak in settings), onboarding flow + gate in the root layout, coach tips rotation.
**Acceptance:** fresh install → onboarding → choices persisted; drills replay with the same seed; all content renders in both themes with no clipping at 1.3× font scale.

### Phase 12: Settings, polish, release readiness
**Tasks:** Settings screen complete (§4.5), Reset all data, About + disclaimer ("Not affiliated with the National Mah Jongg League. Practice Card hands are original."), haptics everywhere per §11.8, motion per §11.8, accessibility pass (labels, roles, focus order), empty states everywhere, a new app icon & splash (a simple ivory tile with a jade edge and a stylised flower; generate it as SVG → PNG at the required sizes; adaptive icon layers), `eas.json` with `development`, `preview`, `production` profiles (no secrets), version 1.0.0.
**Acceptance:** `npx expo-doctor` clean (if network allows); a manual checklist (below) passes on iOS simulator/Android emulator or web.

### Manual QA checklist (final)
- [ ] First launch → onboarding → land on the Game tab.
- [ ] Create 4 players; play 8 hands, including a self-pick jokerless, a discard, a wall game, an adjustment, an edit, and an undo; end; settle-up correct; share text OK.
- [ ] Helper: Charleston suggestions never include jokers; Playing discard + call check; Scout with 2 opponents.
- [ ] Cards: duplicate, edit, import, export; the active card is used in Record-hand and the Helper.
- [ ] Learn: all topics; both drills.
- [ ] Dark mode everywhere; 1.3× font; VoiceOver labels on tiles.
- [ ] Kill the app mid-session → reopen → the session is intact.

---

## 14. Testing strategy & definition of done

- **Unit (Jest, node env) for `src/domain/**`:** target ≥ 95% line coverage, enforced with `coverageThreshold` on `src/domain`.
- **Component (RNTL) for key screens/components:** as listed per phase.
- **Property tests:** use the seeded `mulberry32`. No extra library is needed; write small loops.
- **No snapshot tests of whole screens** (they are brittle). Small description-string snapshots are fine.
- **Definition of done for any PR:** the phase acceptance is ticked, `npm run check` is green locally and in CI, there are no TypeScript `any`, no console warnings in tests, and new UI has a screenshot (light + dark) in the PR.

---

## 15. Future ideas (not v1, keep the architecture open)

- **Camera rack scan** (on-device tile recognition) to skip manual entry.
- **5-player tables** with a rotating sitter and optional betting.
- **Shared game night**: one phone keeps score while others view live (needs a backend; later).
- **Card QR sharing** (`react-native-qrcode-svg`) for a club organiser to share a custom practice card.
- **Year rollover**: "New card season" flow that archives last year's card while keeping stats.
- **Discard tracker by voice**: "five dot" → seen counter.
- **Probability of completion** (Monte Carlo over the live wall) to replace the simple liveOuts heuristic.
- **Widgets / Live Activity** showing game-night standings.
