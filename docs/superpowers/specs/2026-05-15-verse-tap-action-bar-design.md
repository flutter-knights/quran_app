# Verse-tap Action Bar — Design

**Date:** 2026-05-15
**Branch:** feature/001-surah-list
**Status:** Design approved, awaiting plan

---

## 1. Goal

When a user taps a verse on the mushaf page:

1. The verse is highlighted inline on the page.
2. A non-modal bottom action bar slides up with 5 actions: **Tafsir**, **Translation**, **Play**, **Bookmark**, **Share**.
3. Tapping elsewhere on the page dismisses the bar and clears the highlight.
4. The highlight persists while the bar is open; tapping **Play** starts audio from that verse and the highlight follows playback.
5. The highlight is rendered as a single all-rounded shape when adjacent lines connect horizontally. (Already implemented in `AyahHighlightPainter`.)
6. When Quran is playing, the page view auto-swaps to follow the playback verse across page boundaries.

## 2. Scope

**In scope:**
- Slide-up action-bar widget at scaffold level driven by existing `MushafCubit.highlightedAyah`.
- Gesture rebinding: remove long-press modal; tap becomes the sole entry point.
- Auto-swap of `PageView` to follow `playingAyah` across pages.
- New `bookmarks` feature (Clean Arch slice, Hive-persisted).
- `share_plus` integration for Share action.
- Tafsir and Translation as "coming soon" snackbar stubs.

**Out of scope (separate future specs):**
- Tafsir reader screen.
- Translation reader screen.
- Bookmarks list / management screen.
- Share-message customisation, deep-link payloads.

## 3. Architecture

### 3.1 Widget tree (after change)

```
MushafPage (Scaffold)
└── BlocListener<MushafCubit>           ← NEW: watches playingAyah → animateToPage
    └── Column
        ├── Expanded
        │   └── PageView.builder         ← unchanged controller, onPageChanged
        │       └── MushafPageView       ← tap-only GestureDetector
        ├── AyahActionBar                ← NEW, animated slide-up
        └── MushafPageNumberText         ← unchanged
```

### 3.2 State ownership

| State | Owner | Notes |
|---|---|---|
| `highlightedAyah` (user-tapped) | `MushafCubit` (existing) | Drives painter highlight AND bar visibility |
| `playingAyah` (auto from playback) | `MushafCubit` (existing, via `CurrentAyahNotifier`) | Drives painter AND auto-swap |
| `currentPage` | `MushafCubit` (existing) | |
| `bookmarks: Set<AyahIdentifier>` | New `BookmarkCubit` (app-level singleton) | Loaded from Hive on app start |

No new screen-state cubit is introduced. The bar is a pure presentation of `MushafCubit.highlightedAyah`.

### 3.3 Deletions

- `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_sheet.dart` — removed.
- `onLongPressStart` handler in `MushafPageView` — removed.

### 3.4 Highlight shape requirement (hard requirement)

**The highlight must be treated as ONE all-rounded shape when consecutive line-rects of the same ayah connect horizontally.**

An ayah may wrap over multiple lines on the mushaf page. Each line is a separate `NormalizedRect` in `AyahBoundEntity.lines`. When two consecutive line-rects are vertically adjacent (i.e., their horizontal extents overlap or touch with no visible gap between bottom-of-line-N and top-of-line-N+1), they MUST be rendered as a single merged path with rounded *outer* corners only — not as separate per-line rounded rectangles.

- Separate per-line rounded rectangles → forbidden when lines connect.
- Single merged path with continuous fill, rounded only at the four outer corners, with step-corner transitions where the line widths differ → required.
- When a vertical gap exists between two line-rects of the same ayah (e.g., the ayah spans across a paragraph break or visual divider), each connected group is its own merged path.

This is already implemented in `AyahHighlightPainter._buildMergedPath` and `_groupAdjacentRects`. The spec lists it explicitly so it is a contractual requirement protected by tests, not an incidental behaviour that can regress. Both `highlightColor` (user-highlight) and `playingColor` (playback-highlight) must obey this rule.

## 4. Interaction flow

### 4.1 Tap an ayah (no current highlight)

1. `MushafPageView` hit-test → `MushafCubit.toggleHighlight(ayah)`.
2. `MushafCubit` emits `highlightedAyah = ayah`.
3. `AyahHighlightPainter` paints the merged rounded shape.
4. `AyahActionBar` `BlocBuilder` sees non-null → `AnimatedSlide` offset goes `(0, 1) → (0, 0)`.

### 4.2 Tap a different ayah while bar is open

1. `toggleHighlight(other)`: since `state.highlightedAyah != other`, emits `highlightedAyah = other` (does not clear in between).
2. Painter swaps highlight using its existing fade animation.
3. Bar stays open; rebuilds with the new ayah for its action handlers.

### 4.3 Tap the same ayah / tap empty page area

1. `_handleTap` checks hit-test:
   - Hit returns the same ayah as current highlight → `toggleHighlight` clears it (existing behaviour).
   - Hit returns `null` AND current highlight is non-null → call new `MushafCubit.clearHighlight()`.
2. `MushafCubit` emits `highlightedAyah = null`.
3. Bar slides down; painter fades highlight out.

### 4.4 Swipe to another page

`PageView.onPageChanged → MushafCubit.setPage` already emits `clearHighlighted: true`. Bar auto-dismisses. No new code.

### 4.5 Press Play on the bar

1. `PlaybackCubit.playFromAyah(ayah)`.
2. `MushafCubit.clearHighlight()` so the user-highlight doesn't double up with the playback highlight.
3. Bar slides down (bound to `highlightedAyah`).
4. Playback advances → `CurrentAyahNotifier` → `MushafCubit.playingAyah` updates → painter draws playback highlight.

### 4.6 Press Bookmark / Share / Tafsir / Translation

| Button | Action | Bar behaviour |
|---|---|---|
| Bookmark | `BookmarkCubit.toggle(ayah)` + snackbar "Bookmarked" / "Removed bookmark" | stays open |
| Share | `share_plus`'s `Share.share(<verse text> + ' — surah:ayah')` | stays open |
| Tafsir | snackbar `S.of(context).coming_soon` | stays open |
| Translation | snackbar `S.of(context).coming_soon` | stays open |

### 4.7 Auto-swap on playback

1. `BlocListener<MushafCubit, MushafState>` in `MushafPage`, `listenWhen: prev.playingAyah != curr.playingAyah`.
2. On change: `targetPage = QuranPageService.getPageForAyah(ayah.surah, ayah.ayah)`.
3. If `targetPage - 1 != _controller.page?.round()`, call `_controller.animateToPage(targetPage - 1, duration: 300ms, curve: easeInOut)`.

Edge cases:
- `playingAyah → null` (playback stopped): no swap.
- `playingAyah` on current page: no swap.
- Controller not attached: bail.
- User manually swiped during playback: next ayah change yanks them back (accepted).
- `onPageChanged` firing during animateToPage triggers `setPage → clearHighlighted: true` — fine, no user-highlight during playback.

## 5. New `bookmarks` feature slice

Folder layout per architecture rules:

```
lib/features/bookmarks/
├── domain/
│   ├── repositories/
│   │   └── bookmark_repository.dart        ← abstract: getAll, toggle, isBookmarked
│   └── usecases/
│       ├── get_bookmarks.dart              ← Either<Failure, Set<AyahIdentifier>>
│       └── toggle_bookmark.dart            ← Either<Failure, bool> (true = now bookmarked)
├── data/
│   ├── datasources/local/
│   │   └── bookmark_local_data_source.dart ← Hive box 'ayah_bookmarks'
│   └── repositories/
│       └── bookmark_repository_impl.dart
├── presentation/
│   └── cubit/
│       ├── bookmark_cubit.dart             ← loads on init, exposes toggle()
│       └── bookmark_state.dart             ← Set<AyahIdentifier>, loaded flag, error flag
└── bookmarks_di.dart                       ← initBookmarks(): registers data source, repo, use cases, cubit
```

**Storage shape.** A single Hive box `ayah_bookmarks` storing a `List<String>` under key `'all'`. Each entry is `'{surah}:{ayah}'`. No new TypeAdapter required.

**Cubit lifetime.** `LazySingleton` (app-level), matching the architecture rule note that allows singletons for app-level cubits. Loaded on app start; the Mushaf screen consumes it via `BlocProvider.value` or directly via `sl<BookmarkCubit>()`.

**Hive init.** Open the box in `config/hive_config.dart` following the existing pattern for other boxes. Reuse `AyahIdentifier` from `quran_playback` — no entity duplication.

**Reuse policy.** `AyahIdentifier` lives in `quran_playback/domain/entities/`. The bookmarks feature reuses it directly. If this cross-feature dependency feels wrong later, lift `AyahIdentifier` into a shared `core/` location — defer until a second consumer needs the move.

## 6. `AyahActionBar` widget

**File:** `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar.dart`

**Composition:**

```dart
BlocBuilder<MushafCubit, MushafState>(
  buildWhen: (p, c) => p.highlightedAyah != c.highlightedAyah,
  builder: (ctx, state) {
    final visible = state.highlightedAyah != null;
    return IgnorePointer(
      ignoring: !visible,
      child: AnimatedSlide(
        offset: visible ? Offset.zero : const Offset(0, 1),
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOutCubic,
        child: AnimatedOpacity(
          opacity: visible ? 1 : 0,
          duration: const Duration(milliseconds: 180),
          child: Material(
            elevation: 8,
            color: Theme.of(ctx).colorScheme.surface,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsetsDirectional.symmetric(horizontal: 8, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _BarButton(icon: ..., label: S.of(ctx).tafsir,       onTap: () => _onTafsir(ctx)),
                    _BarButton(icon: ..., label: S.of(ctx).translation, onTap: () => _onTranslation(ctx)),
                    _BarButton(icon: ..., label: S.of(ctx).play,        onTap: () => _onPlay(ctx, state.highlightedAyah), prominent: true),
                    _BookmarkButton(ayah: state.highlightedAyah),
                    _BarButton(icon: ..., label: S.of(ctx).share,       onTap: () => _onShare(ctx, state.highlightedAyah)),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  },
)
```

**Stale-ayah safety.** Handlers read `state.highlightedAyah` at tap time (closed over the rebuild) and no-op if `null`. `IgnorePointer` blocks taps during slide-out.

**Bookmark button.** A small dedicated widget that wraps `BlocBuilder<BookmarkCubit, BookmarkState>` (`buildWhen` filters to membership changes for this specific ayah). Renders filled/outlined star. Tap → `toggle(ayah)` + snackbar.

**Icons.** Use `hugeicons` (already in pubspec) — final icon constants chosen during implementation.

## 7. Auto-swap implementation

In `_MushafPageState`:

```dart
@override
Widget build(BuildContext context) {
  return BlocListener<MushafCubit, MushafState>(
    listenWhen: (p, c) => p.playingAyah != c.playingAyah,
    listener: (ctx, state) => _maybeSwapToPlayingAyah(state.playingAyah),
    child: Scaffold(...),
  );
}

void _maybeSwapToPlayingAyah(AyahIdentifier? ayah) {
  if (ayah == null) return;
  if (!_controller.hasClients) return;
  final currentIdx = _controller.page?.round();
  if (currentIdx == null) return;
  final targetIdx = sl<QuranPageService>().getPageForAyah(ayah.surah, ayah.ayah) - 1;
  if (currentIdx == targetIdx) return;
  _controller.animateToPage(
    targetIdx,
    duration: const Duration(milliseconds: 300),
    curve: Curves.easeInOut,
  );
}
```

`QuranPageService` is already registered in DI by the playback feature.

## 8. Localisation

New strings in both ARB files (`lib/l10n/intl_en.arb`, `lib/l10n/intl_ar.arb`):

- `tafsir`
- `translation`
- `play`
- `bookmark`
- `share`
- `coming_soon`
- `bookmark_added`
- `bookmark_removed`
- `bookmark_save_failed`
- `share_failed`

All accessed via `S.of(context)` per localisation rules. No `S.of(context)` calls in domain layer.

RTL: `MainAxisAlignment.spaceAround` and `EdgeInsetsDirectional` ensure correct mirroring in Arabic locale.

## 9. Error handling

| Path | Failure | UX |
|---|---|---|
| `BookmarkRepository` Hive read/write | `CacheException → CacheFailure` (via `Either`) | Snackbar "Couldn't save bookmark" (`bookmark_save_failed`); state stays consistent |
| `Share.share` platform exception | wrap in try/catch | Snackbar `share_failed` |
| `playFromAyah` | existing behaviour | unchanged |
| Auto-swap with detached controller | guarded `hasClients` check | silent no-op |
| Auto-swap with out-of-range page | `QuranPageService` is authoritative; trust it | no extra guard |

All `Either<Failure, T>` returns per architecture rules.

## 10. Edge cases

- Tap during slide-out animation: `IgnorePointer` blocks.
- Bookmark toggle before initial load: `BookmarkCubit` no-ops while `loaded == false`. In practice it loads on app start before mushaf opens.
- Auto-swap during another auto-swap in flight: `animateToPage` is overridden — fine, the latest call wins.
- `setState` after dispose during async snackbar callbacks: guard with `if (!context.mounted) return;`.

## 11. Testing strategy

1. **`MushafCubit`** — add tests for: `toggleHighlight(sameAyah)` clears, switching to different ayah does not pass through null, new `clearHighlight()` method.
2. **`BookmarkCubit`** — load, toggle-add, toggle-remove, persistence via fake `BookmarkRepository`.
3. **`BookmarkRepositoryImpl`** — wraps data source, maps `CacheException → CacheFailure`.
4. **`BookmarkLocalDataSource`** — fake Hive box, round-trip set persistence.
5. **`AyahActionBar` widget** —
   - `highlightedAyah == null`: bar offscreen, `IgnorePointer` on.
   - `highlightedAyah != null`: bar onscreen, taps accepted.
   - Play taps: `PlaybackCubit.playFromAyah` called, `MushafCubit.clearHighlight` called.
   - Bookmark tap: `BookmarkCubit.toggle` called, snackbar shown.
6. **`MushafPage` auto-swap** — mock `QuranPageService` and `MushafCubit`; emit `playingAyah` mapped to page 5 with controller on page 1; verify `animateToPage(4, ...)`.
7. **`MushafPageView` gesture** — tap empty area while highlight exists → `MushafCubit.clearHighlight` called.
8. **`AyahHighlightPainter` merged-shape rule (§3.4)** — given an ayah with three vertically-adjacent line-rects, the painter emits ONE `Path` (not three `RRect`s). Verify via a paint-recording test: count the number of `drawPath` calls per ayah equals the number of connected groups, not the number of lines. Also verify that when a vertical gap is injected between line-rects, the count splits accordingly.

## 12. Files changed (summary)

**Modified:**
- `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` — add `BlocListener` for auto-swap and slot in `AyahActionBar`.
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart` — remove long-press handler; tap calls `clearHighlight` on empty hit.
- `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart` — add `clearHighlight()` (thin wrapper over `emit(copyWith(clearHighlighted: true))`).
- `lib/config/hive_config.dart` — open `ayah_bookmarks` box on init.
- `lib/core/di/dependency_injection.dart` — call new `initBookmarks()`.
- `lib/l10n/intl_en.arb`, `lib/l10n/intl_ar.arb` — new strings.
- `pubspec.yaml` — add `share_plus`.

**New:**
- `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar.dart`.
- `lib/features/bookmarks/` (full slice as in §5).

**Deleted:**
- `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_sheet.dart`.

## 13. Definition of done

- Tap-empty / tap-same-ayah / tap-different-ayah behave as specified in §4.
- Bar slides up under 200ms, slides down under 200ms.
- Play button starts audio AND clears user-highlight; playing-highlight then follows recitation.
- Auto-swap fires when `playingAyah` crosses a page boundary; lands within ~300ms.
- Bookmarks survive an app restart.
- Share button opens native share sheet with verse text + reference.
- Tafsir and Translation show localised "coming soon" snackbar.
- All new strings in both `intl_en.arb` and `intl_ar.arb`.
- RTL layout verified in Arabic locale.
- Highlight rendering obeys §3.4: vertically-adjacent line-rects of the same ayah render as ONE merged rounded path; this holds for both user-highlight and playback-highlight, and is protected by tests in §11.8.
- Test plan in §11 implemented and green.
