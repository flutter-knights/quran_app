# Last-Read Card Reliability — Design

- **Date:** 2026-06-13
- **Branch:** `feature/mushaf-reading-experience`
- **Status:** Approved (brainstorming) — pending spec review → writing-plans
- **Workstream:** D of a 4-part program (A control surface · B background audio/basmala · C prayer notifications · **D last-read reliability**). A, B, C are specced+planned. Each workstream is its own brainstorm → spec → plan → build cycle.

## Problem statement

The "Continue reading" card (home) can fail to reflect where the user actually left off, and can show a meaningless position. The user asked to investigate the card "if in corner case fail."

## Root causes (verified in code)

1. **Last-read is persisted only in `dispose()`.** `mushaf_page.dart:110–129` saves `LastRead(page, ayah)` in `dispose()`. `dispose()` does **not** run when the OS kills a backgrounded app, on force-stop, or on crash — so an entire reading session's progress is lost. This is the main reliability gap.
2. **No page clamping.** `LastReadRepositoryImpl.save` (`last_read_repository_impl.dart:26`) writes `value.page` straight to Hive with no bounds check. In scroll mode `_onScroll` rounds the scroll offset to a page (`mushaf_page.dart:144`); any stray 0 or 605 would persist verbatim and then be used as a navigation target.
3. **Ayah 0 renders as "ayah 1".** With Workstream B, `currentAyah` can be `(surah, 0)` (basmala). `computeSurahProgress` (`surah_reading_progress.dart:31`) clamps `ayah` to `(1,total)` but keeps `ayahBased = true`, so the card shows "ayah 1" for the basmala header — confusing.

(First-launch `null` is handled; the page/ayah-mismatch case is benign given `computeSurahProgress` derives the surah from the ayah when present.)

## Goals

- The card reflects the user's most recent page even if the app is killed in the background.
- Persisted page is always a valid mushaf page (1..604).
- The basmala header (ayah 0) and a null ayah render as a start-of-surah / page position, never "ayah 0/1".

## Non-goals

- Changing the `LastRead` schema / Hive `typeId` (no migration).
- Tracking sub-ayah scroll position or reading time.
- Changing the card's visual design (only its progress-derivation for ayah 0).
- Changing how navigation consumes `last.page` beyond the clamp.

---

## Design

### D1 — Persist when it matters (debounced on-change + on background + dispose flush)

Make `_MushafPageState` (`mushaf_page.dart`) save last-read at three moments, all routed through one private `_saveLastRead()` that reads the current `MushafCubit`/`PlaybackCubit` state:

- **On page change (debounced).** Listen to `MushafCubit` `currentPage` changes (a `BlocListener` with `listenWhen: a.currentPage != b.currentPage`, or reuse the existing scroll/page listeners) and schedule `_saveLastRead()` behind a ~800 ms debounce `Timer`. Debouncing avoids a write per page-boundary during fast continuous scrolling while still capturing the page the user settles on.
- **On app background.** Make the state a `WidgetsBindingObserver`; in `didChangeAppLifecycleState`, when state is `paused` or `inactive`, cancel the debounce and `_saveLastRead()` immediately. This is the moment before the OS may kill the app, so it is the key durability lever.
- **On dispose (flush).** Keep the existing `dispose()` save (cancel the debounce timer first), as the clean-exit path.

`_saveLastRead()` captures `page = MushafCubit.currentPage` and `ayah = highlightedAyah ?? PlaybackCubit.currentAyah` (unchanged from today), guarded by `mounted`/`isClosed`, and swallows errors (`.catchError`) so a persistence failure never affects reading.

### D2 — Clamp the page at the repository chokepoint

In `LastReadRepositoryImpl._to` / `save`, clamp `page` to `1..604` before constructing the Hive model, so every writer (current and future) is protected:
```dart
LastReadHiveModel _to(LastRead v) => LastReadHiveModel(
      page: v.page.clamp(1, 604),
      surah: v.ayah?.surah,
      ayah: v.ayah?.ayah,
    );
```
(Reads stay tolerant; no migration.)

### D3 — Treat ayah 0 / null as start-of-surah (page-based)

In `computeSurahProgress` (`surah_reading_progress.dart`), treat a basmala/zero ayah exactly like a missing ayah: change the `if (last.ayah != null)` guard to `if (last.ayah != null && last.ayah!.ayah > 0)`. The page-based branch then renders the page/surah position, so the card never shows "ayah 0/1" for the basmala header. The surah is still derived correctly: when the ayah is `(surah,0)` it falls through to the page-based branch whose `_firstSurahOfPage(last.page)` resolves the surah.

---

## Architecture / component map

| Unit | Responsibility | Action |
|---|---|---|
| `mushaf_page.dart` `_MushafPageState` | Debounced + lifecycle + dispose saves via one `_saveLastRead()` | Modify |
| `LastReadRepositoryImpl` | Clamp page 1..604 on save | Modify |
| `surah_reading_progress.dart` `computeSurahProgress` | ayah 0/null → page-based | Modify |

`LastRead`, `LastReadHiveModel`, `LastReadLocalDataSource`, `LastReadCubit`, and the card widgets are unchanged.

## Testing

- **`computeSurahProgress` unit tests** (pure): `ayah == 0` → `ayahBased == false`, page-based fraction, correct surah; `ayah == null` → unchanged page-based; `ayah > 0` → unchanged ayah-based.
- **`LastReadRepositoryImpl` tests**: `save(LastRead(page: 0))` persists page 1; `save(page: 700)` persists 604; valid pages pass through; ayah round-trips.
- **Mushaf save-trigger widget test** (scoped — never the full suite, per the asset-regeneration caveat): a page change followed by the debounce window calls `LastReadCubit.save` with the new page; an `AppLifecycleState.paused` event saves immediately (use `tester.binding.handleAppLifecycleStateChanged` / dispatch the observer). Mock/spy the cubit.
- **Manual gate (document in PR):** read to page N → background the app (don't reopen the reader) → cold-start → the card shows page N (not the page from a previous session); scroll fast through many pages then settle → the settled page is saved once; basmala position shows the surah/page, not "ayah 0".

## Risks / caveats

- **Debounce vs. abrupt kill:** a kill within the debounce window before a background event could miss the last 1–2 page turns; the `paused` save closes the common case (user backgrounds the app). Acceptable.
- **Lifecycle double-save:** `inactive`→`paused` may both fire; saving is idempotent (same key) so a duplicate write is harmless. Cancel the debounce timer in the lifecycle handler to avoid a late overwrite with a stale value.
- **Observer lifecycle:** add the `WidgetsBindingObserver` in `initState` and remove it in `dispose` to avoid leaks.
