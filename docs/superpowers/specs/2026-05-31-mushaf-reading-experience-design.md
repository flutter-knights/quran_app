# Mushaf Reading Experience — Design

Date: 2026-05-31
Status: Approved (full vision; build sequenced into 4 phases)

## Goal

A comprehensive enhancement of the Mushaf reading screen
(`lib/features/surah/presentation/pages/mushaf/`) that makes it read like a real
Madani mushaf and adds serious playback/study tooling. Six areas:

1. **Printed chrome** — surah name (right) and juz name (left) rendered as QCF
   glyphs inside the page's decorative header band; page-number ornament at
   bottom-center. Replaces today's floating top/bottom metadata bars.
2. **Eye-comfort theming** — six tuned paper themes + an in-app page-brightness
   slider, controlled from a proper reading-settings sheet (mirrored into the
   main Settings screen).
3. **Reading modes** — page-by-page (default) and continuous vertical scroll;
   rotating to landscape enters continuous scroll (fit-width, large text). Chrome
   hides in scroll/landscape.
4. **Playback power** — play a from→to ayah range with per-ayah and per-range
   repeat counts plus an infinite option; type-editable counters; redesigned
   mini/expanded player.
5. **Overlay-aware positioning** — the page never lets the active ayah hide under
   the player (scale-to-safe-area in page mode; auto-scroll in scroll mode).
6. **Tafsir** — a draggable peek→read→full-screen sheet; Al-Muyassar bundled
   offline, other tafsirs (Ibn Kathīr, Saʿdī, Ṭabarī) fetched online.

This supersedes the chrome/overlay parts of
`2026-05-29-mushaf-reading-controls-design.md`. Visual references:
`.superpowers/mockups/01..09-*.html`.

## Guiding decisions (locked)

- Chrome is **printed on the paper** (philosophy A), not floating bars.
- **Six** paper themes ship; brightness slider is **in-app** (page-dim overlay).
- Page mode is **always the default**; scroll is a toggle; rotate → scroll.
- Repeat supports **both** dimensions (each-ayah ×, range ×) **and** infinite.
- Play default = **tapped ayah → end of surah**.
- All numeric counters are **type-editable** (keypad) plus +/− steppers.
- Page-mode avoidance = **scale page into safe area**; scroll-mode = auto-scroll.
- Tafsir = **draggable peek→full sheet**; **one tafsir bundled offline + rest online**.

---

## Architecture overview

Clean architecture is preserved (domain / data / presentation, `dartz` Either,
Cubits, GetIt). New work is additive and isolated:

- **Surah feature** gains the chrome renderer, paper/brightness theming, reading
  modes, and overlay-avoidance plumbing in `MushafCubit`/`MushafState`.
- **Playback feature** gains range + repeat state and the redesigned player; the
  audio sequencing in `PlaybackCubit` is extended, not rewritten.
- **New Tafsir feature** (`lib/features/tafsir/`) with its own domain/data/
  presentation, following the existing feature template.
- **Settings** gains mushaf paper, brightness, and reading-mode persistence
  (already a `HydratedCubit` — extend `SettingsModel`).

Each unit below states what it does, how it's used, and what it depends on.

---

## Phase 1 — Reading feel & chrome

### 1.1 Printed glyph chrome

**What:** A `MushafChrome` overlay drawn *as part of the page layout* (not the
floating dock). In page mode it renders:
- **Header band** positioned over the existing `_accent.png` frame: surah name on
  the start (right, RTL) side, juz name on the end (left) side, both as QCF
  glyphs.
- **Page-number ornament** centered at the bottom margin (Arabic-Indic digits in
  a small framed pill).

**How:** New widget `MushafPrintedChrome` inside
`pages/mushaf/widgets/`. Given `(pageNumber, MushafPaperColors)` it reads page
meta from the existing `QuranMetaService`/quran package and renders:
- `quran.getQcfSurahName(surah)` and `quran.getQcfJuzName(juz)` using a newly
  registered font family **`QCF2BSML`** (asset `assets/QCF2BSMLfonts/QCF2BSML.ttf`).
- Color: surah/juz glyphs use the paper's `accent`/`ink`; the band frame is the
  accent layer already in the PNG.

A page can contain more than one surah. For the header band we show the surah of
the **first ayah on the page** (matches physical mushaf convention); if a new
surah starts mid-page we still label by the page's leading surah. Juz likewise
uses the page's leading position.

**Depends on:** quran package (`getQcfSurahName`, `getQcfJuzName`,
`getPageData`, `getJuzNumber`), the `QCF2BSML` font registration in
`pubspec.yaml`, paper colors.

**Implementation risk (verify during build):** confirm `QCF2BSML.ttf` renders the
codepoints in `qcf_surah_juz_names.dart` for all 114 surahs + 30 juz. If a glyph
is wrong/missing, fall back to `quran.getSurahNameArabic()` for that entry. This
verification is a required task, gated before Phase 1 sign-off.

**Hizb/Rub:** removed from the header (kept mushaf-authentic: surah + juz only).
The hizb/rub value moves into the index sheet (§1.4) as secondary info.

### 1.2 Six eye-tuned paper themes

**What:** Replace the current 5-paper palette with six tuned themes, each a
`MushafPaperColors(background, ink, accent)`:

| Key | Name | Background | Ink | Accent |
|-----|------|-----------|-----|--------|
| `cream` | Cream (default day) | `#FBF4E3` | `#2A2419` | `#2E5244` |
| `sepia` | Sepia | `#EDE0C4` | `#3A2A14` | `#8A6D3B` |
| `green` | Soft Green | `#E2EBE2` | `#1B3A26` | `#3C7A55` |
| `gray` | Soft Gray | `#E8E6E1` | `#33302A` | `#6B6456` |
| `night` | Night | `#14161A` | `#E8D9A8` | `#C9A227` |
| `slateNight` | Slate Night | `#10141A` | `#D6E2EC` | `#4878A0` |

Principles: no pure white, no pure black, warm ink at night to avoid halation.
The `MushafPaper` enum (`core/constants/mushaf_paper.dart`) and
`MushafPaperColors` (`presentation/utils/mushaf_paper_colors.dart`) are updated;
the default-paper case keeps deriving from the active palette where applicable.

**How rendered:** unchanged mechanism — `ColorBlendMode.srcIn` tints the page PNG
(`ink`) and accent PNG (`accent`) over `background`.

### 1.3 In-app page-brightness

**What:** A `pageBrightness` value (0.3–1.0, default 1.0) dims the page only,
independent of system brightness.

**How:** A non-interactive `Opacity`/black-scrim overlay over the page layer
(controls and sheets stay full brightness). Stored in settings; applied in
`MushafPageView`.

### 1.4 Reading-settings sheet + floating dock + index

Because surah/juz/page are now printed, the floating chrome becomes an **action
dock**, not a metadata bar.

- **Floating dock** (bottom-center, glassy/blurred, toggled by tap): `⚙` reading
  settings · `▶` play page · `📑` bookmark. Top corners: `‹` back, `☰` index.
- **Reading-settings sheet** (opened by `⚙`): large tappable paper previews (6),
  page-brightness slider, reading-mode toggle (Page ⇄ Scroll). Replaces the
  cramped bottom-bar swatches.
- **Index sheet** (`☰`): jump by surah / juz / page; shows hizb/rub for context.
  (May reuse existing surah-list/search infra; full scope deferred — at minimum a
  "go to page" + juz jump.)
- Settings mirror: add Mushaf section to `settings_page.dart` for default paper,
  brightness, and reading mode so choices persist across sessions.

**Immersive toggle:** tap on empty page toggles the dock + back/index buttons.
In scroll/landscape the printed header/footer hide entirely (see Phase 3).

### 1.5 State & persistence (Phase 1)

- `SettingsModel` (HydratedCubit) gains: `mushafPaper` (already present; surface
  it), `pageBrightness: double`, `readingMode: enum {page, scroll}`.
- `MushafState` keeps `chromeVisible`; dock visibility reuses it.

---

## Phase 2 — Overlay-aware playback

### 2.1 Playback state extensions

`PlaybackState` (in `features/quran_playback/.../playback_state.dart`) adds:

- `rangeStart: AyahIdentifier?`, `rangeEnd: AyahIdentifier?` — the from→to range
  (single surah for v1).
- `eachAyahRepeat: int` (1–99), `rangeRepeat: int` (1–99).
- `infiniteRepeat: bool` and `infiniteTarget: enum {eachAyah, range}` — which
  count the ∞ applies to.
- runtime counters: `currentAyahPlayCount`, `currentRangePass`.

`PlaybackCubit` extends `_handleNextAyah()`/sequencing:
- After an ayah finishes, if `currentAyahPlayCount < eachAyahRepeat` (or infinite
  on eachAyah) → replay same ayah.
- Else advance; at `rangeEnd`, if `currentRangePass < rangeRepeat` (or infinite on
  range) → restart at `rangeStart`; else stop.
- The existing `AyahSequenceService` is reused for advance, bounded by the range.

### 2.2 Play entry points

- Dock `▶` / page FAB → `rangeStart = first ayah of page`,
  `rangeEnd = end of that surah` (default), respecting basmala handling already
  in `PlaybackCubit.playSelected`.
- Tap an ayah (chrome visible) → `rangeStart = tapped ayah`,
  `rangeEnd = end of surah`.
- Range editable in the expanded player.

### 2.3 Redesigned player (mini + expanded)

Replaces `ayah_playback_overlay.dart` with a two-state widget:

- **Mini-player:** now-playing label + live repeat status ("تُكرّر آية ٥ من ٣"),
  reciter/speed chips, transport (prev · replay · play/pause · next · ⚙/expand),
  ayah progress bar. Auto-anchors top/bottom opposite the active ayah (reuse
  `highlightedAyahCenterY`).
- **Expanded panel:** Range steppers (from / to), Repeat boxes (each-ayah ×,
  range ×) + ∞ toggle, reciter + speed selectors. Every numeric field supports
  +/− and direct keypad entry.

### 2.4 Counter input & validation (confirmed — 8 rules)

1. **From bounds:** `1 ≤ from ≤ verseCount`; 0/blank → `1`.
2. **To bounds:** `from ≤ to ≤ verseCount`; over last → clamp to last ayah.
3. **From > To:** the other end auto-follows (to = from); never errors.
4. **Single surah** (v1): range cannot cross into the next surah from steppers.
5. **Repeat counts:** `1 ≤ n ≤ 99` finite; blank/0 → `1`; ∞ covers "forever".
6. **Infinite override:** ∞ on disables that count field (shows ∞); off restores
   the last number.
7. **Live edit:** changing range mid-playback restarts cleanly from new `from`;
   repeat changes apply on the next loop.
8. **Invalid text:** non-numeric ignored; out-of-range reverts to last valid.

Validation lives in a pure helper (`PlaybackRangeValidator`) so it's unit-tested
independent of UI.

### 2.5 Overlay-aware positioning

- **Page mode:** when the player is visible, `MushafPageView` constrains the page
  into the area above the player and scales the page to fit (animated 0.4s on
  show/hide). The full page stays visible; nothing is hidden.
- **Scroll mode:** as playback advances, auto-scroll so the active ayah stays
  centered in the band above the player (uses existing ayah bounds to compute
  target offset).

---

## Phase 3 — Reading modes

### 3.1 Page mode (default)

Existing horizontal RTL `PageView` with printed chrome. Unchanged engine, plus
Phase 1 chrome.

### 3.2 Continuous scroll

**What:** A vertical lazy list of pages, each fit to viewport width.
- Printed header band hidden; page boundaries shown as subtle separators
  ("··· صفحة N ···").
- Current page surfaces as a small floating pill that fades while scrolling.
- Tap-to-play and highlight still work via existing ayah bounds (bounds are
  normalized, so they map under fit-to-width scaling).

**How:** New `MushafScrollView` (sibling of `MushafPageView`) built on
`ScrollablePositionedList` (or `ListView.builder` + `cacheExtent` tuning). The
active mode is chosen by `SettingsModel.readingMode` + orientation.

**Implementation risk:** 604 large PNGs — use lazy item building, bounded
`cacheExtent`, and precache only neighbors (extend the existing ±1 precache
logic). Verify memory on low-end devices; the prior
`2026-05-14-mushaf-rendering-leak-design.md` constraints apply.

### 3.3 Rotation → scroll

On landscape orientation the screen forces continuous scroll (fit-width = large
text), hides all printed/floating chrome except a minimal tap-revealed dock.
Returning to portrait restores the user's chosen mode. Orientation handled at the
`MushafPage` level (OrientationBuilder); no global app rotation lock needed for
this screen.

---

## Phase 4 — Tafsir

### 4.1 Feature module

New `lib/features/tafsir/` (domain/data/presentation):
- **Entity:** `TafsirEntry(source, surah, ayah, arabicText)`.
- **Source enum:** `TafsirSource { muyassar (offline), ibnKathir, saadi, tabari }`.
- **Repository port:** `TafsirRepo.getTafsir(source, AyahIdentifier) → Either<Failure, TafsirEntry>`.
- **Data:**
  - Offline datasource reads bundled Al-Muyassar JSON (asset, ~1–2MB), keyed by
    surah:ayah.
  - Remote datasource fetches other sources via API (Dio), with on-device cache
    (Hive) so re-opened ayahs work offline after first fetch.
- **Use case:** `GetTafsir`.

**Implementation risk:** source/license the offline Muyassar JSON and pick the
online API (e.g. quran.com or spa5k tafsir endpoints). Confirm licensing before
bundling. Network/parse failures surface as `Failure` → the sheet shows a
skeleton then a retry state (see Loading States rule).

### 4.2 Tafsir sheet (peek → read → full)

A single `DraggableScrollableSheet`-based `TafsirSheet`:
- **Peek (~38%):** ayah text + tafsir start, over the dimmed page.
- **Read (~78%):** source chips switch tafsirs; `‹ ▶ ›` move prev/next ayah or
  play it; tafsir body scrolls.
- **Full (100%):** dedicated study view — font-size control, save/share.

Entry: the existing `ayah_action_popover.dart` "Tafsir" button (currently a
"coming soon" snackbar) opens the sheet for the long-pressed ayah.

**Loading:** while fetching, show a shimmer `Skeletonizer` placeholder matching
the tafsir text layout (per `.claude/rules/loading-states.md`) — never a bare
spinner.

---

## Cross-cutting: error handling

- All new repos return `Either<Failure, T>`; cubits map failures to user-facing
  states (retry affordances; skeletons during load).
- Font fallback for missing glyphs (§1.1).
- Audio range/repeat respects the existing `_inFlightAyah` race guard.
- Tafsir offline-first; online fetch failures degrade gracefully to a retry card.

## Testing

- **Unit:** `PlaybackRangeValidator` (all 8 rules + edge cases); range/repeat
  sequencing logic in `PlaybackCubit` (each-ayah loop, range loop, infinite,
  boundary advance); paper-color mapping; chrome surah/juz resolution per page.
- **Widget:** counter type-entry + clamping; reading-settings sheet toggles;
  overlay-avoidance layout (page scales when player shown); tafsir sheet states
  (peek/read/full, loading skeleton, retry).
- **Golden (optional):** printed chrome band per theme; mini-player anchoring.
- **Manual matrix:** the QCF glyph verification (114 surah + 30 juz), scroll
  performance on a low-end device, landscape rotation.

## Build sequence

1. **Phase 1 — Reading feel & chrome** (priority): font registration + glyph
   verification, printed chrome, six papers, brightness, reading-settings sheet,
   floating dock, settings mirror.
2. **Phase 2 — Overlay-aware playback:** range + repeat state/sequencing,
   redesigned mini/expanded player, validator, page-scale/auto-scroll avoidance.
3. **Phase 3 — Reading modes:** continuous scroll view + rotate-to-scroll.
4. **Phase 4 — Tafsir:** module, offline Muyassar + online sources, draggable
   sheet, popover wiring.

Each phase ships independently and gets its own implementation plan.

## Out of scope (v1)

- Cross-surah playback ranges (rule 4).
- Two-page landscape spread (rotation maps to scroll instead).
- Translation display (separate from tafsir; existing "coming soon").
- Bundling multiple tafsirs fully offline (only Muyassar offline in v1).
