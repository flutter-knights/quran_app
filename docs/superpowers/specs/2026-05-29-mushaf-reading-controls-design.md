# Mushaf Reading Controls — Design

Date: 2026-05-29
Status: Approved (Approach 1 — extend existing cubits)

## Goal

Improve the mushaf reading screen with: tap-to-toggle top/bottom chrome, a
top metadata bar (juz · surah · hizb/rub), a bottom bar with mushaf-only paper
color themes + page number + play, an ayah long-press **popover** (replacing the
bottom sheet), and a reciter control in the existing playback overlay. Visuals
and palettes are adapted from `Quran App (1).html`.

## Interaction model

- **Swipe L/R** → page navigation (unchanged `PageView`).
- **Tap, chrome hidden** → show chrome (top + bottom bars).
- **Tap empty area, chrome visible** → hide chrome.
- **Tap a verse, chrome visible** → select the verse (highlight) → the floating
  **playback overlay** opens, anchored opposite the verse (top/bottom, animated)
  so it never covers the selected line.
- **Long-press a verse** (any state) → **ayah action popover** above/below the
  verse: bookmark · share · tafsir (soon) · translation (soon). **No play, no
  reciter.**
- **Bottom ▶ FAB** → play the page from its first ayah.

Reciter is changed only inside the playback overlay. Verse-level play starts by
tap-selecting a verse while chrome is visible.

## A. State

`MushafState` adds `bool chromeVisible` (default `false`). `MushafCubit` adds
`toggleChrome()` and `setChrome(bool)`. Verse selection reuses the existing
`toggleHighlight` + `highlightedAyahCenterY` plumbing (already drives the
playback overlay's top/bottom anchoring). Clearing chrome does not clear an
active playback target.

Gesture handling lives in `MushafPageView`'s existing `GestureDetector`:
`onTapUp` branches on hit-test (verse vs empty) and `chromeVisible`;
`onLongPressStart` opens the popover for the hit verse.

## B. Chrome widgets

- **`MushafTopBar`** — flush to the top edge, glassy (semi-transparent + blur),
  bottom border. Start side: `الجزء N`. Center: surah name (Amiri). End side:
  `حزب M · ربع R`. Reads `QuranMetaService.getPageMeta(currentPage)`.
- **`MushafBottomBar`** — flush to the bottom edge, top border. Contents: paper
  swatches (5) at start · page number centered · **▶ FAB** at end. Replaces the
  current standalone `MushafPageNumberText` footer and the headphones FAB.
- Both animate in/out (slide + fade) driven by `chromeVisible`.
- The **playback overlay** remains a separate floating layer above the bars; it
  shows/animates based on the selected/playing verse, independent of chrome.

## C. Paper themes

- **`MushafPaper` enum** in `core/constants/mushaf_paper.dart`:
  `defaultPaper, parchment, night, sky, mint` (pure Dart).
- Presentation extension `MushafPaperX` (in `config/theme/` or
  `features/.../presentation/utils/`) exposing, given a `BuildContext`/app
  scheme: `background`, `ink` (body tint), `accent` (frame+rosette tint).
  - `defaultPaper` → app `mushafBg` / `onSurface` / `secondary`.
  - parchment `#f0e6d2 / #3a2a14 / #8a6d3b`
  - night `#0d0f12 / #e8d9a8 / #c9a227`
  - sky `#eaf1f7 / #1a3550 / #3c6e9e`
  - mint `#e4ede4 / #1b3a26 / #3c7a55`
- **Persistence**: add `MushafPaper mushafPaper` (default `defaultPaper`) to
  `Settings` entity + `SettingsModel` (constructor/copyWith/fromMap/toMap/props)
  and `SettingsCubit.updateMushafPaper()`. Persists via the existing
  HydratedCubit. `fromMap` parses by `.name` with `orElse: defaultPaper`.
- **Rendering**: `MushafPageView` reads the active paper (via `SettingsCubit`)
  and applies `ink` to the **body** `srcIn` tint, `accent` to the **accent**
  `srcIn` tint, and `background` to the page fill — replacing today's hardcoded
  `onSurface` / `secondary`. The two PNG layers are tinted separately.
  Ayah highlight/playing colors derive from the paper accent/ink.

## D. Hizb / rub data

- **`QuranMetaService`** (`features/quran_playback/domain/services/`) with
  `PageMeta getPageMeta(int page)` → `{surah, juz, hizb (1–60), rub (1–4 within
  hizb)}`. Juz via `quran.getJuzNumber`; hizb/rub from a bundled **const
  240-quarter (ربع) boundary table** (`surah:ayah` start of each quarter), in
  the data layer. Computed from the page's first ayah
  (`QuranPageService.getFirstAyahOfPage`). Registered in DI (lazy singleton).
- The boundary table is the authoritative standard Madani division; values are
  fixed constants, spot-checked in tests.

## E. Ayah popover

- **`AyahActionPopover`** (new widget) shown via `OverlayEntry`, positioned from
  the verse bounds (above if the verse is in the lower half, below if upper),
  horizontally centered, with a small caret. Actions: bookmark (toggles via
  `BookmarkCubit`), share (`share_plus`), tafsir (coming-soon snackbar),
  translation (coming-soon snackbar). Dismiss on outside tap / scroll / page
  change.
- `ayah_long_press_sheet.dart` is **removed**; `MushafPageView._handleLongPress`
  shows the popover instead.

## F. Playback overlay reciter control

- Add a reciter affordance to `AyahPlaybackOverlay._Body` (e.g. a chip showing
  the current reciter's Arabic name; tap → reciter picker menu calling
  `PlaybackCubit.setReciter`). Keep existing transport/speed/close and the
  animated top/bottom anchoring.

## Testing

- `MushafCubit`: chrome toggle; verse-select sets highlight; clearing chrome
  keeps playback target.
- `QuranMetaService`: hizb/rub spot-checks — juz 1 (Fatiha) → juz 1/hizb 1/rub 1;
  a known mid-quran quarter boundary; juz 30 start; last page.
- Settings paper-theme persistence round-trip (`toMap`/`fromMap`).
- `AyahActionPopover` placement: above when verse low, below when high.
- Existing mushaf tests (dispose, playback overlay, bounds) keep passing.

## Out of scope

- Tafsir/translation content (snackbar placeholders only).
- Per-paper PNG image filters (web mockup) — N/A; we tint two alpha masks.
- Auto-hide timer for chrome (chrome toggles on tap only).
