# Mushaf Image-Rendering Design

**Date:** 2026-05-15
**Status:** Approved — ready for implementation planning
**Branch:** `feature/001-surah-list`

## Problem

The current mushaf screen renders each page by composing text spans from QCF (King Fahd Complex) fonts — one font per page (`QCF_P001`–`QCF_P604`) plus a shared font (`QCF_P000`) for headers/basmala/juz markers. Rendering is correct, but cold-render on first swipe to a never-seen page is laggy: the framework has to register a fresh per-page font, parse the page entity, build the inline span tree, and shape glyphs synchronously on the main isolate. Caching the parsed page (`MushafPageCache`) and spans (`MushafSpansCache`) only masks the cost on revisits — forward swiping into unseen pages still stutters.

Existing mitigations explored or in place:
- LRU caches for parsed pages and spans (helps revisits, not first visits).
- An unused `parseMushafPageInIsolate` helper (parsing was never the bottleneck — font shaping was).
- A `CurrentAyahNotifier` bridge from `PlaybackCubit` to drive playback highlight.

## Goal

Replace the text-rendering pipeline with pre-rendered transparent PNG assets — one per page, 604 total — bundled with the app. Highlight ayahs at runtime using bounding rects produced at the same time as the PNGs. Decouple correctness of mushaf glyphs from runtime font shaping entirely.

## Non-Goals

- Multi-resolution asset variants. Single 1536px width.
- Page-number container glyph hunting. Page numbers render as a runtime text overlay below the PNG, in a regular Arabic font.
- Backwards compatibility with the text-rendering path. It will be deleted.
- Mid-page surah-transition cosmetics beyond what the existing layout already produces.
- Drag-to-select multi-ayah selection. (Single-ayah highlight only; revisit later if needed.)

## Approach summary

1. **Build-time:** A `flutter test`-driven generator renders each of the 604 pages with the existing QCF font pipeline (already proven by `test/spikes/render_page_spike_test.dart`) and emits a `page_NNN.png` + `page_NNN.json` pair. Generator is committed-output, not run on CI.
2. **Runtime:** App ships only the PNGs and bounds JSON. The 604 QCF font files leave the bundle. A new `MushafPageView` widget paints `Image.asset` (tinted via `BlendMode.srcIn`) under a `CustomPainter` highlight overlay, with a single `GestureDetector` doing hit-testing against the normalized bounds.

## Architecture

### Domain layer (`lib/features/surah/domain/`)

```dart
class MushafPageImage {
  final int pageNumber;
  final List<AyahBound> ayahs;
}

class AyahBound {
  final int surah;
  final int ayah;
  final List<NormalizedRect> lines;
}

class NormalizedRect {
  final double x, y, w, h; // 0..1, against PNG dimensions
}
```

Derived data (juz number, hizb, surah name) is not on the entity — it's looked up at runtime from the `quran` package using `(surah, ayah)` from the first bound entry. Keeps JSON minimal and avoids duplicating package-owned data.

Repository contract:

```dart
abstract class MushafPageRepository {
  Future<MushafPageImage> getPage(int pageNumber);
}
```

Use case:

```dart
class GetMushafPage {
  Future<MushafPageImage> call(int pageNumber);
}
```

The existing `MushafPageEntity` (with text fields, surah headers indexes, basmala indexes, span identifiers, etc.) is deleted.

### Data layer (`lib/features/surah/data/`)

`MushafLocalDataSource.getPage(int)`:
- Reads `assets/mushaf/bounds/page_${n.toString().padLeft(3, '0')}.json` via `rootBundle.loadString`.
- Decodes into `MushafPageImage`.
- In-memory `Map<int, MushafPageImage>` cache, no eviction (total bounds JSON ≈ 1.8MB).
- PNG path is constructed by convention in the presentation layer, not stored in the entity.

Deleted: `MushafPageCache`, `MushafSpansCache`, `parseMushafPageInIsolate`, every span-building helper.

### Presentation layer (`lib/features/surah/presentation/`)

**Cubit state**

```dart
class MushafState {
  final int currentPage;            // 1..604
  final AyahKey? highlightedAyah;   // user tap
  final AyahKey? playingAyah;       // from PlaybackCubit
}

class AyahKey {
  final int surah;
  final int ayah;
}
```

**Cubit actions**

| Trigger | Method | Effect |
|---|---|---|
| Swipe to page N | `setPage(n)` | Updates `currentPage`, clears `highlightedAyah` |
| Tap ayah | `toggleHighlight(key)` | Sets or clears `highlightedAyah` |
| Long-press ayah | `openActionSheet(key, context)` | Calls `showModalBottomSheet`; does NOT change `highlightedAyah` |
| `PlaybackCubit` emits | listener in cubit | Updates `playingAyah`. Auto-following the playing page is deferred (see Open Questions). |

**Widget tree**

```
MushafPage
└── Scaffold
    ├── AppBar (existing — reads cubit for surah/juz names)
    └── Column
        ├── Expanded → PageView.builder(itemCount: 604, ...)
        │             itemBuilder builds MushafPageView(pageNumber: 604 - i)
        └── Text(EasternArabicDigits(state.currentPage))
```

```
MushafPageView (one PageView item)
└── AspectRatio(1 / 1.82)
    └── Stack
        ├── Image.asset('assets/mushaf/pages/page_NNN.png',
        │     color: theme.onSurface, colorBlendMode: BlendMode.srcIn,
        │     gaplessPlayback: true, filterQuality: medium)
        ├── CustomPaint(painter: _AyahHighlightPainter(bounds,
        │     highlighted, playing, animation))
        └── GestureDetector (full-stack hit-test)
              onTapUp:  cubit.toggleHighlight(_hitTest(localPos))
              onLongPressStart: cubit.openActionSheet(_hitTest(localPos), context)
```

**Data flow into a single page view**

Each `MushafPageView` is constructed by `PageView.builder` with its `pageNumber`. On init it calls `GetMushafPage(pageNumber)` through GetIt to load its own bounds (~1ms — synchronous in practice once the data source's `Map` is warm). It does not read bounds from `MushafCubit`; the cubit's responsibility is the global highlight/page state, not per-page data. A blank placeholder is rendered for the first frame if bounds aren't yet decoded.

`PageView.builder` keeps Flutter's default `cacheExtent` (1 page on each side). The parent `MushafPage` calls `precacheImage` for `current ± 1` when the `PageController` fires, warming Flutter's `ImageCache` before the user swipes that direction.

### Theming

Single source of truth: `BlendMode.srcIn` tints the black PNG using `Theme.of(context).colorScheme.onSurface`. Theme switches re-paint instantly with no asset duplication.

### Highlight overlay

`_AyahHighlightPainter` iterates the page's `ayahs`, finds the entries matching `playingAyah` (drawn under) and `highlightedAyah` (drawn over), and for each `NormalizedRect` denormalizes to the layout size and paints a rounded-rect fill. Colors are lerped over ~180ms via an `AnimationController` owned by `MushafPageView`.

The painter's `shouldRepaint` returns true only when `highlightedAyah`, `playingAyah`, or `animation.value` change. Repaints stay local to the painter — the Image and GestureDetector don't rebuild.

### Hit-testing

One `GestureDetector` per page, not per ayah:
- Avoids 5–15 widgets per cached page eating layout cost.
- The detector's `onTapUp`/`onLongPressStart` callbacks give a `localPosition`. Normalize against the rendered size, then iterate `bounds` (O(ayahs-on-page)) and return the first `AyahBound` whose any `lines` rect contains the point. Falls through to no-op if the tap lands between rects (margins, page number, etc.).

### Long-press action sheet

`AyahActionSheet` widget in `lib/features/surah/presentation/widgets/`. Contents:

1. ▶ Play from here — `PlaybackCubit.startFrom(key)`
2. 📑 Tafsir — navigate to existing tafsir route
3. ⭐ Bookmark — toggle in existing bookmark store
4. 📋 Copy text — `Clipboard.setData` with `quran.getVerse(s, a)`
5. 🔗 Share — system share sheet with verse + reference

Sheet is opened by the cubit via `showModalBottomSheet`; results are forwarded to existing services.

## Build-time generation pipeline

### Files

- `test/tools/generate_mushaf_assets_test.dart` — loops pages 1..604, runs the same logic as `test/spikes/render_page_spike_test.dart`.
- `test/tools/woff_to_ttf.dart` — moved from the spike folder, unchanged.

The spike files in `test/spikes/` are deleted as part of the cutover.

### Per-page rendering

For each page N in 1..604:

1. Load `QCF_P000` and `QCF_P${NNN}` via the existing WOFF→SFNT converter + `FontLoader`. Single-threaded execution is mandatory (`--concurrency=1`) to avoid `FontLoader` races.
2. Read page data through `MushafLocalDataSource` (the *current* implementation, kept temporarily for the generator's use).
3. Lay out a `TextPainter` at `minWidth = maxWidth = 1536` with `textAlign: center`, `textDirection: rtl`, `maxLines: 15`. Layout matches the validated spike: header band reserved for top surah headers (image overlay + separately-painted centered name), basmala on line 2 if present, verses below.
4. Convert `Picture` → `Image` at 1536 × (1536 × 1.82) = 1536 × 2796, encode PNG, write to `assets/mushaf/pages/page_NNN.png`.
5. Call `getBoxesForSelection` on each ayah's character range with `BoxHeightStyle.includeLineSpacingMiddle`. Normalize x/y/w/h to 0..1 against image dimensions (y offset by `topReserve` when a top header was present). Write to `assets/mushaf/bounds/page_NNN.json`.

### JSON format

```json
{
  "page": 2,
  "ayahs": [
    {
      "surah": 2,
      "ayah": 1,
      "lines": [
        {"x": 0.4123, "y": 0.1456, "w": 0.1789, "h": 0.0612}
      ]
    }
  ]
}
```

5 decimal places (pixel-accurate at 4K). Multi-line ayahs produce multiple `lines` entries.

### Validation

The generator test asserts, per page:
- PNG > 10KB (catches empty/blank renders from font-load failures).
- `ayahs.isNotEmpty`.
- Every ayah has `lines.isNotEmpty`.

A separate one-off `test/tools/verify_mushaf_assets_test.dart` walks all 604 generated JSONs and asserts every `(surah, ayah)` from the `quran` package appears exactly once — guards against pages dropping or duplicating ayahs.

### Workflow

1. Update a font, a layout constant, or generator code.
2. `flutter test test/tools/generate_mushaf_assets_test.dart --concurrency=1`.
3. `flutter test test/tools/verify_mushaf_assets_test.dart`.
4. `git add assets/mushaf/ && git commit`.

Generator is **not** in CI — assets are committed output. CI keeps only a smoke test that runs the generator for page 50 and asserts PNG/JSON shape.

### Pubspec consequences

Removed:
- 604 `QCF_PNNN` font registrations
- The `assets/fonts/QCF/` font-asset entry

Added:
- `assets/mushaf/pages/`
- `assets/mushaf/bounds/`

## Change order

Each step leaves `flutter analyze` clean. Only step 4 changes user-visible behavior; step 5 is a cleanup pass.

1. **Generator first.** Move spike to `test/tools/`, parameterize over 1..604, run, commit the generated `assets/mushaf/` directory. The app doesn't use these assets yet.
2. **New entity + data source.** Add `MushafPageImage` alongside the old entity. Add a new data source `MushafImageLocalDataSource` reading the bounds JSON. Wire it into a new use case `GetMushafPageImage`. Existing text-rendering code untouched.
3. **New page widget behind a debug route.** Build `MushafPageView` as a sibling to today's mushaf widget under a debug-only route so it can be compared side-by-side on real device.
4. **Cut over.** Swap the production mushaf route from the old widget to `MushafPageView`. Old code still compiles but is unreachable.
5. **Delete.** Remove the files listed below, rename the new types back to canonical names (`MushafLocalDataSource`, `GetMushafPage`, `MushafPage`), strip QCF fonts from `pubspec.yaml`, commit.

### Files deleted outright

- `lib/features/surah/data/datasources/mushaf_page_cache.dart`
- `lib/features/surah/data/datasources/mushaf_spans_cache.dart`
- `lib/features/surah/presentation/pages/mushaf/widgets/ayah_text_span_builder.dart`
- `lib/features/surah/presentation/pages/mushaf/widgets/basmala_text.dart`
- `lib/features/surah/presentation/pages/mushaf/widgets/surah_header.dart`
- `parseMushafPageInIsolate` helper(s) and their wiring
- `test/spikes/render_page_spike_test.dart`
- `test/spikes/woff_to_ttf.dart`

### Files rewritten

- `lib/features/surah/domain/entities/mushaf_page.dart`
- `lib/features/surah/data/datasources/mushaf_local_data_source.dart`
- `lib/features/surah/data/repositories/mushaf_page_repository_impl.dart`
- `lib/features/surah/domain/usecases/get_mushaf_page.dart`
- `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`
- `lib/features/surah/presentation/pages/mushaf/*` (whole subtree)
- `pubspec.yaml`

## Testing strategy

| Layer | Test |
|---|---|
| Generator | CI smoke test runs generator for page 50 only; asserts PNG > 10KB and JSON has ayahs. Full 604-page generation is local only. |
| Data source | Golden JSON fixture for one page, parsed by `MushafLocalDataSource`, asserts entity shape. |
| Cubit | `bloc_test` for `setPage`, `toggleHighlight`, and the `PlaybackCubit`-bridge listener. |
| Widget | Two `goldenTest`s — header page (page 2) and vanilla page (page 100), both in light and dark themes — catches tint and positioning regressions. |
| Verify-assets | `verify_mushaf_assets_test.dart` asserts every `(surah, ayah)` from the `quran` package is covered exactly once across all 604 bounds JSONs. Runs locally pre-commit when assets change. |

## Performance expectations

- **Cold-render latency:** Image asset decode (~5–10ms) vs current 50–150ms for font registration + span build + shaping. Subjective lag on first swipe into a new page should disappear.
- **Memory:** Single decoded PNG at 1536×2796 ≈ 17MB raw RGBA. Flutter's `ImageCache` default is 100MB / 1000 entries — accommodates 5–6 pages comfortably. Adjacent pre-cache covers swipe flow.
- **Bundle size:** Estimated 80–100MB for 604 PNGs at 1536px. Replaces the existing ~70MB of QCF fonts, so net delta is roughly +10–30MB.
- **JSON parse cost:** ~1ms per page. No isolate needed.

## Open questions / decisions deferred

- **Page number font.** Runtime text overlay is the decision; specific Arabic font choice (Amiri vs system Arabic vs an existing app font) is a presentation-time pick, not architectural.
- **Auto-follow during playback.** Off by default; revisit after wiring is in place.
- **Page-aspect tuning.** 1.82 matches the spike's framing of page 2; if any of the 604 pages produces visible overflow or excess whitespace at this aspect, the generator's aspect constant gets tuned and the asset set is regenerated.

## Out of scope

- Recitation-driven scroll within a page (line-by-line scroll synced to audio).
- User notes/annotations on ayahs.
- Multi-mushaf support (Madani only, as today).
- Text-search inside the mushaf (handled by the existing search feature, which uses the `quran` package directly).
