# Mushaf Control Surface & Interaction Redesign — Design

- **Date:** 2026-06-13
- **Branch:** `feature/mushaf-reading-experience`
- **Status:** Approved (brainstorming) — pending spec review → writing-plans
- **Workstream:** A of a 4-part program (**A mushaf control surface** · B background audio/basmala · C prayer notifications · D last-read reliability). C is already specced+planned. Each workstream is its own brainstorm → spec → plan → build cycle.

## Problem statement

The Mushaf reading screen's controls are confusing and incomplete:

1. **Two control surfaces appear at once.** Tapping an ayah shows the playback mini-player while the floating action dock is still up — two stacked controls. Bad UX.
2. **The rotate button fights the OS.** It force-locks orientation via `SystemChrome.setPreferredOrientations`, conflicting with the device's own auto-rotate and getting stuck.
3. **No navigation chrome.** There is no back button and no page indicator / page-jump — only the printed surah/juz chrome and the system back gesture.
4. **Reading-mode toggle is inconsistent.** It uses a native `SegmentedButton` instead of the app's `AppSegmentedSelector` (used for the 12h/24h and language switchers).
5. **Brightness is unusable in place.** The slider lives in a bottom sheet that covers the page, so you can't see the brightness change while dragging.
6. **"Save" is a hack.** The bookmark button saves the *first ayah* of the page (ayah-level), with no page description and no visual marker — not how you'd mark a place in a real mushaf.

## Root causes (verified in code)

- **Dual surface:** `MushafActionDock` is visible when `chromeVisible`; `AyahPlaybackOverlay` is visible when `highlightedAyah != null || isOverlayPinned`. The two visibilities are independent. Pressing **Play** calls `setChrome(false)` (so that path is clean), but **tapping an ayah** sets `highlightedAyah` without clearing `chromeVisible`, so the dock (bumped up 76px via `AnimatedPadding`) and the mini-player both render. (`mushaf_page.dart:236–274`, `mushaf_action_dock.dart`, `ayah_playback_overlay.dart`.)
- **Rotate:** `MushafActionDock._onRotate` force-locks orientation (`mushaf_action_dock.dart:65–73`); `mushaf_page.dart:119` resets it on dispose. Landscape→scroll is *already* automatic via `_effectiveMode` (`mushaf_page.dart:204–209`), so the manual lock is redundant and harmful.
- **No top chrome:** the `Scaffold` in `mushaf_page.dart` has no `appBar`.
- **Reading-mode toggle:** `reading_settings_sheet.dart:84–99` uses `SegmentedButton<MushafReadingMode>`; the reusable control is `AppSegmentedSelector<T>` (`lib/core/widgets/design/app_segmented_selector.dart`).
- **Brightness:** `reading_settings_sheet.dart:73–79` is an `onChanged`-only `Slider` inside a modal sheet whose default dim barrier hides the page.
- **Bookmark hack:** `_BookmarkDockButton` (`mushaf_action_dock.dart:102–133`) bookmarks `QuranPageService.getFirstAyahOfPage(currentPage)` via the ayah-level `BookmarkCubit`. Ayah bookmarks are also created by the per-ayah `ayah_action_popover.dart:304` and listed in `bookmarks_page.dart` — so **ayah bookmarks must stay**; page-saving is a separate concept.

## Goals

- One coherent control surface — the idle controls and the player are never both on screen.
- A slim, optional top bar: back, current surah/juz/page, tap-to-jump.
- Device-driven rotation only (no manual orientation lock).
- Reading-mode toggle uses `AppSegmentedSelector`.
- Brightness adjustable while the page stays visible.
- Real page-saving: a page-level bookmark with a surah/ayah description and a physical-mushaf **ribbon** marker, surfaced in the Bookmarks screen — without disturbing ayah bookmarks.

## Non-goals

- Changing ayah bookmarks or the ayah action popover.
- Changing the playback engine / mini-player internals (Workstream B owns background audio + basmala).
- Changing continuous-scroll/page-mode rendering or the printed chrome.
- Reworking the Bookmarks screen beyond adding a "Pages" section.

---

## Design

### A1 — Unified control surface (browse ⇄ player, mutually exclusive)

Keep the well-tested `AyahPlaybackOverlay` (the **player face**) and replace the floating `MushafActionDock` with a **browse bar** anchored at the same bottom position. A single visibility rule makes them mutually exclusive and animates one cross-fading into the other, so it reads as one surface.

Define `playerActive = highlightedAyah != null || isOverlayPinned || playingAyah != null`.

- **Bottom — player face** (`AyahPlaybackOverlay`): visible whenever `playerActive` (independent of `chromeVisible`, so it persists through playback — unchanged behavior).
- **Bottom — browse face** (new `MushafBrowseBar`): visible when `chromeVisible && !playerActive`. Contents: `[reading settings] · [▶ Play page] · [🔖 Save page]`. (Rotate button removed; bookmark becomes the page-save toggle — see A5.)
- The 76px `AnimatedPadding` stacking hack is removed; both faces share one bottom anchor and cross-fade via their existing slide/opacity animations.
- `_onPlay` no longer calls `setChrome(false)` — mutual exclusion already hides the browse face when playback starts, and keeping chrome on lets the top bar remain available.

This is intentionally an additive refactor (not a literal widget merge): it preserves `AyahPlaybackOverlay`'s careful "stable context" sheet handling while delivering a single-surface experience.

### A2 — Top bar (`MushafTopBar`)

A slim, glassy top bar (matching the dock's frosted style) shown when `chromeVisible` (independent of `playerActive`, so it's available during playback too):
- **Leading:** back button → `context.pop()` (go_router).
- **Center:** current surah name + juz + "page N", sourced from the existing `resolvePrintedChrome(currentPage)` and `MushafCubit.currentPage`.
- **Action:** tap the center (or a small page icon) → **page-jump** sheet: a number field (1–604, Western/Arabic-Indic accepted) and/or a slider; on submit, jump there (`_pageController.jumpToPage` in page mode, `_scrollController.jumpTo(_scrollOffsetFor(page))` in scroll mode).
- Fades/slides in with the same chrome animation as the bottom surface.

### A3 — Remove the rotate-lock button

- Delete the rotate `_DockButton` and `_onRotate` from the browse bar (it is not carried over from the dock).
- Remove the `SystemChrome.setPreferredOrientations([])` reset in `mushaf_page.dart` dispose (nothing locks orientation anymore). The app follows the device sensor; `_effectiveMode` keeps mapping landscape→scroll automatically.

### A4 — Reading-mode toggle → `AppSegmentedSelector`

Replace the `SegmentedButton<MushafReadingMode>` in `reading_settings_sheet.dart` with `AppSegmentedSelector<MushafReadingMode>`:
- options: `page` → `S.pageByPage`, `scroll` → `S.continuousScroll`.
- `onChanged: cubit.updateReadingMode`. Keep the same `ValueKey('reading-mode-toggle')` so existing widget tests still find it.

### A5 — Brightness live-preview

Make `ReadingSettingsSheet` stateful and the brightness slider preview-aware:
- `Slider.onChangeStart` → `_dragging = true`; `onChangeEnd` → `_dragging = false`. `onChanged` still calls `cubit.updatePageBrightness` so the page scrim updates live.
- Wrap the whole sheet body in an `AnimatedOpacity` that drops to ~0.12 while `_dragging`, back to 1.0 on release.
- `ReadingSettingsSheet.show` uses `barrierColor: Colors.transparent` and `backgroundColor: Colors.transparent` with the sheet drawing its own surface, so when the body fades the **page behind is fully visible** (the default dim barrier would otherwise hide it). Tapping outside still dismisses.

### A6 — Page bookmarks + ribbon + description

A new **page-bookmark** feature, parallel to the existing ayah `BookmarkCubit` (which is untouched). Mirrors the established bookmark architecture (Hive-backed, GetIt-registered, Cubit-driven).

**Domain (`lib/features/bookmarks/...` or a sibling `page_bookmarks` feature):**
- `PageBookmarkRepository`: `getAll() → Set<int>`, `toggle(int page) → bool`, `isBookmarked(int) → bool`.

**Data:**
- `PageBookmarkLocalDataSource` over a Hive box `page_bookmarks` (store `List<int>` of page numbers).
- `PageBookmarkRepositoryImpl` mapping exceptions → failures (dartz `Either` per the repo convention).

**Presentation:**
- `PageBookmarkCubit` + `PageBookmarkState { Set<int> pages }`, provided app-wide (next to `BookmarkCubit` in `main.dart`).
- **Save control** (browse bar): toggles `currentPage`'s bookmark; icon reflects saved state.
- **Ribbon** (`MushafPageRibbon`): a tactile silk-ribbon hanging from the **top-trailing** corner of a page, rendered inside `MushafPageView` when that page is bookmarked (`BlocBuilder<PageBookmarkCubit>`); shown in both page and scroll modes. Tapping the ribbon removes the bookmark with a snackbar **Undo**.
- **Description helper** `describePage(int page, {required bool isArabic})`: from `quran.getPageData(page)`, list each surah + ayah range on the page, e.g. `"البقرة ٣٠–٤٨"` (Arabic-Indic numerals for `ar`), joining multiple surahs with `،`/`,`. Skips the basmala pseudo-range (`start==end==0`). Lives in presentation utils (it formats with locale).

**Bookmarks screen:**
- Add a **"Pages"** section to `bookmarks_page.dart` listing saved pages (sorted ascending), each row showing the page number + `describePage(...)`; tap → navigate to the mushaf at that page (reuse the existing mushaf route + `extra` page argument).

### Design quality (apply during implementation)

Apply `frontend-design` principles when building the visuals:
- The top bar and browse bar share the existing frosted-glass language (blur + translucent dark fill, rounded) so the chrome feels like one system.
- The browse↔player transition is a smooth cross-fade/slide at a shared anchor — no jump, no double surface mid-transition.
- The ribbon should read as cloth: a notched/forked tail, a subtle drop shadow, an accent color from the active paper palette, and a short settle animation when a page is saved.

---

## Architecture / component map

| Unit | Responsibility | Notes |
|---|---|---|
| `MushafBrowseBar` (new) | Idle controls: settings · play page · save page | Replaces `MushafActionDock`; visible `chromeVisible && !playerActive` |
| `AyahPlaybackOverlay` (existing) | Player face | Visibility unchanged (`playerActive`); now the *only* bottom surface when active |
| `MushafTopBar` (new) | Back · surah/juz/page · page-jump | Visible `chromeVisible` |
| `MushafPageRibbon` (new) | Per-page saved marker | In `MushafPageView`, driven by `PageBookmarkCubit` |
| `PageBookmarkCubit` / repo / datasource (new) | Page-level bookmarks (Hive `page_bookmarks`) | Mirrors ayah `BookmarkCubit`; app-wide provider |
| `describePage(...)` (new util) | Page → surah/ayah description | Uses `quran.getPageData`; locale-aware |
| `ReadingSettingsSheet` (modify) | Reading settings + brightness preview + `AppSegmentedSelector` | Becomes stateful; transparent barrier |
| `mushaf_page.dart` (modify) | Wire top bar + browse bar; drop rotate reset; page-jump hooks | Stack composition |
| `mushaf_action_dock.dart` (delete) | — | Superseded by `MushafBrowseBar` |

`MushafState` is unchanged — the redesign is driven entirely by the existing `chromeVisible` / `highlightedAyah` / `isOverlayPinned` / `playingAyah` fields plus the new `PageBookmarkCubit`.

## Testing

- **Widget tests (scoped — never the full suite, per the asset-regeneration caveat):**
  - Browse bar and player overlay are never simultaneously visible: tapping an ayah hides the browse bar; dismissing the player restores it (when chrome on).
  - Top bar shows on chrome toggle; back pops; page-jump moves the controller to the requested page (Western + Arabic-Indic input).
  - Reading-mode `AppSegmentedSelector` toggles `readingMode` (key `reading-mode-toggle`).
  - Brightness: dragging sets `_dragging` and fades the body; `onChangeEnd` restores; `updatePageBrightness` is still called.
  - `PageBookmarkCubit.toggle` adds/removes; ribbon appears only on bookmarked pages; description helper output for single- and multi-surah pages (Arabic + English).
- **Unit tests:** `describePage` over representative pages (1, a multi-surah page like 604, a mid-Baqarah page); `PageBookmarkRepositoryImpl` toggle/getAll round-trip.
- **Manual gate:** rotate device with OS auto-rotate on/off → no stuck state; brightness visibly changes while dragging; ribbon renders in page + scroll modes; page-jump in both modes.

## Risks / caveats

- **Bottom-anchor cross-fade:** browse bar and `AyahPlaybackOverlay` occupy the same bottom region; ensure their slide/opacity timings don't visibly overlap (one fully out before the other is in) to avoid a flash of both.
- **Transparent sheet barrier:** with `barrierColor: transparent`, the reading-settings sheet loses the dim backdrop; rely on the sheet's own surface/elevation for separation. Acceptable trade-off for the live brightness preview.
- **Hive box registration:** the new `page_bookmarks` box must be opened in `hive_config` init before the cubit reads it (follow the ayah-bookmark box setup).
- **Page-jump reentrancy:** jumping while a mode switch is mid-flight — guard with `hasClients`/`_scrollPageHeight != 0` like the existing controller code.
