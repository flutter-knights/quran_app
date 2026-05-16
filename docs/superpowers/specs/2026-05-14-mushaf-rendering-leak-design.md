# Design — Mushaf Rendering Memory & Performance Fix

> **Status:** Spec for review
> **Date:** 2026-05-14
> **Scope:** `features/surah/` mushaf rendering pipeline
> **Selected approach:** Approach B (targeted churn fixes + rendering-pipeline rework, no font replacement)

---

## 1. Problem Statement

The mushaf (Quran page) view exhibits three compounding performance symptoms on mobile, especially on 4 GB Android devices:

1. **Swipe jank + Loading flicker.** Every page swipe is heavy and briefly shows a `CircularProgressIndicator` before the page appears, even for pages the user has already visited.
2. **Memory growth across swipes.** RSS climbs with every page visited and never recovers; long sessions trend toward OOM.
3. **Eventual glyph corruption.** After many swipes the rendered glyphs visibly break and the app becomes unreadable until restart.

### Root causes identified

- **`MushafLocalDataSource.getPage` re-parses the entire page on every visit.** No caching of `MushafPageEntity`; revisiting page 42 re-runs the full quran-package parsing and line-break injection. Parsing runs synchronously on the UI isolate.
- **`MushafCubit.loadPage` emits `MushafLoading` unconditionally** before resolving the entity, even when the result is already in memory — this is the Loading flicker.
- **`MushafText` wraps the `RichText` in `BlocBuilder<PlaybackCubit>` keyed on `currentAyah`.** Every ayah tick during autoplay rebuilds the full 15-line span list (all `TextSpan`s, `WidgetSpan(SurahHeader)`s, basmala spans), constructs two new `TextStyle` instances, and re-evaluates `colorScheme` lookups. Worse, this happens on every *live* mushaf page (visible + cacheExtent neighbours), not just the one with the highlighted ayah.
- **`SurahHeader` uses `Image.asset` inside a `WidgetSpan`** in `RichText`. Every span rebuild re-creates the `Image` widget; the colored overlay (`color: colorScheme.onSurface`) forces a tinted decode that does not benefit fully from Flutter's `ImageCache`.
- **604 page-specific QCF fonts** are declared in `pubspec.yaml` (one font family per Quran page). Flutter loads font assets lazily on first reference and **cannot unload them**. Repeated page visits monotonically grow Skia's font glyph atlas; once that atlas exhausts GPU memory on a low-RAM device, glyph pointers go stale and characters render as garbage — the "glyphs break" symptom. *This is a design-level constraint; medium scope cannot eliminate it, only delay it.*
- **`MushafLocalDataSource` is a singleton with mutable parser fields** (`_currentLine`, `_symbolsOnCurrentLine`). They are reset at the top of `getPage`, so it works today, but the pattern is fragile.
- **Repository signature** `Future<MushafPageEntity>` violates the project rule of `Either<Failure, T>` returns (flagged by 2026-05-13 health check).

### Non-goals

- Replacing the 604-font QCF Madani layout with a unified Hafs font (Approach C — declined: user does not want a visual font change).
- Audio preload accounting in `PlaybackCubit`.
- `Either`-return migrations for unrelated features (surah list, hadith, etc.).

---

## 2. Goals & Success Criteria

| # | Goal | How we'll know |
|---|------|----------------|
| G1 | Eliminate Loading flicker on swipe-back to a visited page | `MushafText` widget test asserts cubit emits exactly `[MushafLoaded]` on warm cache; on-device manual check confirms no spinner on backward swipes. |
| G2 | Stop re-parsing pages on repeat visits | Unit test: data-source call counter increments only once per `pageNumber` across swipe sequence. |
| G3 | Stop rebuilding span tree on every ayah tick during autoplay | Widget test: `MushafText.build` instrumentation fires zero times per ayah tick (only `RichText`'s internal paint changes). |
| G4 | Materially delay glyph-atlas exhaustion on 4 GB devices | Manual stress run reaches further than current `main` before glyph corruption, and recovers on `didHaveMemoryPressure` without restart. |
| G5 | Repository conforms to `Either<Failure, T>` | Static check: `mushaf_repo.dart` signature; cubit folds the result. |

Explicit non-goal: G4 is not "never break glyphs" — only Approach C can guarantee that. Medium scope buys us a much higher ceiling but not an infinite one.

---

## 3. Architecture

### 3.1 Component layout

```
features/surah/
├─ data/
│   ├─ datasources/
│   │   ├─ mushaf_local_data_source.dart           (existing — getPage becomes pure, no mutable fields)
│   │   ├─ mushaf_page_cache.dart                  (NEW — LRU<int, MushafPageEntity>, capacity 30)
│   │   └─ mushaf_spans_cache.dart                 (NEW — LRU<int, List<InlineSpan>>, capacity 30)
│   └─ repositories/
│       └─ mushaf_repo_impl.dart                   (returns Either, consults caches)
├─ domain/
│   ├─ repositories/mushaf_repo.dart               (signature → Either<Failure, MushafPageEntity>)
│   └─ usecases/get_mushaf_page.dart               (returns Either)
└─ presentation/
    ├─ cubit/mushaf/
    │   ├─ mushaf_cubit.dart                       (loadPage + loadPageSync; owns spans)
    │   └─ mushaf_state.dart                       (MushafLoaded carries spans)
    ├─ utils/
    │   └─ current_ayah_notifier.dart              (NEW — ValueNotifier<AyahIdentifier?>)
    └─ pages/mushaf/
        ├─ mushaf_pages.dart                       (PageView cacheExtent + memory-pressure observer)
        └─ widgets/
            ├─ mushaf_page_content.dart            (no flicker on warm cache)
            ├─ mushaf_layout.dart                  (RepaintBoundary)
            ├─ mushaf_text.dart                    (ValueListenableBuilder, no BlocBuilder)
            ├─ ayah_text_span_builder.dart         (buildBase + buildHighlightOverlay)
            ├─ surah_header.dart                   (precached ImageProvider)
            └─ basmala_text.dart                   (unchanged)
```

### 3.2 DI changes (`mushaf_di.dart`)

```dart
// new
sl.registerLazySingleton<MushafPageCache>(() => MushafPageCache(capacity: 30));
sl.registerLazySingleton<MushafSpansCache>(
  () => MushafSpansCache(capacity: 30, pageCache: sl()),
);
sl.registerLazySingleton<CurrentAyahNotifier>(
  () => CurrentAyahNotifier(playbackCubit: sl()),
);

// existing — repo now takes the caches
sl.registerLazySingleton<MushafRepository>(
  () => MushafRepositoryImpl(sl(), pageCache: sl()),
);
```

`CurrentAyahNotifier` subscribes to `PlaybackCubit.stream` once at construction; `MushafText` instances read it via `ValueListenableBuilder`.

### 3.3 Layer responsibilities

- **`MushafPageCache`** owns parsed entity lifetime. Single eviction listener notifies `MushafSpansCache`.
- **`MushafSpansCache`** owns the static (no-highlight) spans list. Keyed by `pageNumber`. Spans are built by the cubit on first load and stored here.
- **`MushafRepositoryImpl`** consults the page cache before delegating; wraps data-source exceptions in `CacheFailure`.
- **`MushafCubit`** is the only component that builds spans. State carries `(entity, baseSpans)` so the widget is purely a renderer.
- **`CurrentAyahNotifier`** is the only highlight delivery channel to mushaf text. Widgets do not depend on `PlaybackCubit` directly anymore.

---

## 4. Data Flow

### 4.1 Cold open (first visit to page N)

1. `PageView.builder` builds a `BlocProvider(create: () => sl<MushafCubit>()..loadPage(N))`.
2. `MushafCubit.loadPage(N)` calls `repository.getPage(N)`.
3. Repo: cache miss. Schedules `MushafLocalDataSource.getPage` on a background isolate via `compute()`. Returns `Right(entity)` and stores the entity in `MushafPageCache`.
4. Cubit builds base spans via `AyahTextSpanBuilder.buildBase(context, page, pageNumber, ...)`, stores them in `MushafSpansCache`, applies the current highlight overlay if `CurrentAyahNotifier.value` matches a span on this page, and emits `MushafLoaded(entity, spans)`.
5. `MushafPageContent` renders `MushafLayout` → `MushafText`. `MushafText` wraps `RichText` in `RepaintBoundary` and a `ValueListenableBuilder<AyahIdentifier?>`.

### 4.2 Warm swipe (page already cached)

1. `itemBuilder` creates a fresh `MushafCubit` for the page; calls `loadPageSync(N)`.
2. Repo cache hit returns `Right(entity)` synchronously.
3. Cubit pulls base spans from `MushafSpansCache` (also a hit), applies any highlight overlay, and `emit`s `MushafLoaded` in the same microtask as `create`.
4. `MushafPageContent` never sees `MushafLoading`. No flicker.

### 4.3 Playback tick

1. `PlaybackCubit` emits new state with `currentAyah = (S, A)`.
2. `CurrentAyahNotifier` (subscribed once) writes `value = (S, A)`.
3. Every mounted `MushafText`'s `ValueListenableBuilder` is notified. Each one:
   - Checks whether this page contains ayah `(S, A)` via `page.ayahIdentifiers.contains(...)`.
   - If not, returns the previously-built `RichText` with its existing spans (no rebuild).
   - If yes, calls `AyahTextSpanBuilder.buildHighlightOverlay(baseSpans, page, currentAyah, highlightedStyle)` to produce a new spans list with the affected ayah's `TextSpan` replaced by a highlighted copy, and rebuilds the local `RichText` only.
4. No `BlocBuilder` fires; no `setState` propagates; no other mushaf page paints.

### 4.4 PageView lifecycle

- `PageView.builder` keeps `cacheExtent` ≈ one page width (default behaviour, made explicit). `allowImplicitScrolling` stays `false`.
- One `MushafCubit` per visible/cached page (3 alive at a time). Cubits are disposed when their page is evicted from `cacheExtent`; the caches are owned by singletons so the *data* survives.
- On `WidgetsBindingObserver.didHaveMemoryPressure`, `MushafPage` clears `MushafSpansCache` and trims `MushafPageCache` down to the 5 pages around the current index.

---

## 5. Detailed Component Design

### 5.1 `MushafPageCache`

```dart
class MushafPageCache {
  MushafPageCache({required this.capacity});
  final int capacity;
  final LinkedHashMap<int, MushafPageEntity> _entries = LinkedHashMap();
  final List<void Function(int pageNumber)> _evictionListeners = [];

  MushafPageEntity? get(int pageNumber) {
    final v = _entries.remove(pageNumber);
    if (v != null) _entries[pageNumber] = v; // move to MRU
    return v;
  }

  void put(int pageNumber, MushafPageEntity entity) {
    _entries.remove(pageNumber);
    _entries[pageNumber] = entity;
    while (_entries.length > capacity) {
      final oldest = _entries.keys.first;
      _entries.remove(oldest);
      for (final l in _evictionListeners) l(oldest);
    }
  }

  void addEvictionListener(void Function(int) l) => _evictionListeners.add(l);
  void trimTo(int newCapacity) { /* evict oldest until size <= newCapacity */ }
}
```

### 5.2 `MushafSpansCache`

Same shape, keyed by `pageNumber`, values are `List<InlineSpan>`. Constructed with a reference to `MushafPageCache` so it can `pageCache.addEvictionListener((page) => _entries.remove(page))`.

### 5.3 `MushafRepositoryImpl`

```dart
@override
Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async {
  final cached = pageCache.get(pageNumber);
  if (cached != null) return Right(cached);
  try {
    final entity = await compute(_parsePage, pageNumber);
    pageCache.put(pageNumber, entity);
    return Right(entity);
  } catch (e) {
    return Left(CacheFailure('Failed to parse page $pageNumber: $e'));
  }
}
```

`_parsePage` is a top-level function calling `MushafLocalDataSource().getPage(pageNumber)`. The data source's mutable fields become locals inside `getPage` so a fresh isolate is fine.

### 5.4 `MushafCubit`

State:

```dart
sealed class MushafState {}
final class MushafInitial extends MushafState {}
final class MushafLoading extends MushafState {}
final class MushafError extends MushafState { final String message; }
final class MushafLoaded extends MushafState {
  final MushafPageEntity page;
  final List<InlineSpan> spans; // base spans WITHOUT highlight
  final TextStyle normalStyle;
  final TextStyle highlightedStyle;
}
```

Methods:

- `Future<void> loadPage(int pageNumber, BuildContext context)` — async path; emits `Loading` only on cold load.
- `bool loadPageSync(int pageNumber, BuildContext context)` — checks both caches synchronously; if both hit, emits `Loaded` and returns `true`; otherwise returns `false` (caller awaits `loadPage`).
- `void rebuildSpansForTheme(BuildContext context)` — invalidates `MushafSpansCache[pageNumber]` and rebuilds for theme changes.
- All `emit` sites guarded with `if (isClosed) return;`.

The cubit constructs `normalStyle` and `highlightedStyle` once at load time using `colorScheme` from a passed `BuildContext` (or a captured `ColorScheme` snapshot — preferred, since cubits should not retain `BuildContext`). The `MushafPage` widget reads `Theme.of(context).colorScheme` and passes the snapshot in.

### 5.5 `AyahTextSpanBuilder`

```dart
class AyahTextSpanBuilder {
  static List<InlineSpan> buildBase({
    required MushafPageEntity page,
    required int pageNumber,
    required double fontSize,
    required double lineHeight,
    required ColorScheme colorScheme,
    required TextStyle normalStyle,
  }) { /* same logic, no currentAyah, no highlightedStyle */ }

  /// Returns a NEW list with the matching ayah split into 3 spans.
  /// Returns `baseSpans` unchanged (same reference) when the ayah is null
  /// or not on this page.
  static List<InlineSpan> buildHighlightOverlay({
    required List<InlineSpan> baseSpans,
    required MushafPageEntity page,
    required AyahIdentifier? currentAyah,
    required TextStyle highlightedStyle,
    required TextStyle normalStyle,
  }) {
    if (currentAyah == null) return baseSpans;
    final index = page.ayahIdentifiers.indexWhere(
      (a) => a.surah == currentAyah.surah && a.ayah == currentAyah.ayah,
    );
    if (index < 0) return baseSpans;

    // Find the position in baseSpans that corresponds to this ayah.
    // baseSpans was built in the same order as page.ayahs, with headers
    // and basmala interleaved by their indexes. The corresponding span is
    // the (index)-th TextSpan that has the page's ayah text — i.e., the
    // span at position `_spanPositionForAyah(page, index)`.
    final spanIndex = _spanPositionForAyah(page, index);
    final original = baseSpans[spanIndex] as TextSpan;
    final replacement = TextSpan(
      locale: const Locale('ar'),
      text: original.text,
      style: highlightedStyle,
    );
    return List.of(baseSpans)..[spanIndex] = replacement;
  }
}
```

Note: replacing the entire ayah's span with a highlighted version (rather than splitting into before/highlighted/after) is simpler and matches existing behaviour — the whole ayah is highlighted when its audio plays. The earlier "before/highlighted/after" wording in brainstorming was over-engineered; we keep it whole-ayah.

### 5.6 `MushafText`

```dart
class MushafText extends StatelessWidget {
  final MushafLoaded loaded;
  final int pageNumber;
  final double pageWidth;
  // ...
  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: ValueListenableBuilder<AyahIdentifier?>(
        valueListenable: sl<CurrentAyahNotifier>(),
        builder: (context, currentAyah, _) {
          final spans = AyahTextSpanBuilder.buildHighlightOverlay(
            baseSpans: loaded.spans,
            page: loaded.page,
            currentAyah: currentAyah,
            highlightedStyle: loaded.highlightedStyle,
            normalStyle: loaded.normalStyle,
          );
          return SizedBox(
            width: pageWidth,
            child: RichText(
              textDirection: TextDirection.rtl,
              textAlign: TextAlign.center,
              maxLines: 15,
              overflow: TextOverflow.clip,
              text: TextSpan(children: spans),
            ),
          );
        },
      ),
    );
  }
}
```

When `currentAyah` does not affect this page, `buildHighlightOverlay` returns the exact same `baseSpans` reference. `ValueListenableBuilder` still rebuilds the closure, but the returned `RichText`'s `TextSpan.children` is reference-equal to the previous frame's, so Flutter's `RenderParagraph` short-circuits relayout.

### 5.7 `CurrentAyahNotifier`

```dart
class CurrentAyahNotifier extends ValueNotifier<AyahIdentifier?> {
  CurrentAyahNotifier({required PlaybackCubit playbackCubit}) : super(null) {
    _sub = playbackCubit.stream
        .map((s) => s.currentAyah)
        .distinct()
        .listen((a) => value = a);
  }
  late final StreamSubscription _sub;
  @override
  void dispose() { _sub.cancel(); super.dispose(); }
}
```

`MushafText` does **not** dispose this — it's a `LazySingleton`. The notifier outlives any single mushaf page.

### 5.8 `SurahHeader`

```dart
class SurahHeader extends StatelessWidget {
  // ...
  static const _headerImage = AssetImage('assets/images/header.png');

  @override
  Widget build(BuildContext context) {
    final width = context.width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image(
            image: ResizeImage(_headerImage, width: width.toInt()),
            color: context.colorScheme.onSurface,
            colorBlendMode: BlendMode.srcIn,
            fit: BoxFit.fill,
            gaplessPlayback: true,
          ),
          // ... existing text
        ],
      ),
    );
  }
}
```

`MushafPage.didChangeDependencies` calls `precacheImage(SurahHeader._headerImage, context)` once.

### 5.9 `MushafPage` (memory-pressure observer)

```dart
class _MushafPageState extends State<MushafPage>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ... existing init
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // ... existing dispose
  }

  @override
  void didHaveMemoryPressure() {
    sl<MushafSpansCache>().clear();
    final current = (_pageController.page ?? _pageController.initialPage).round();
    sl<MushafPageCache>().trimAround(current, keep: 5);
  }
}
```

---

## 6. Error Handling

- **Repository signature** becomes `Future<Either<Failure, MushafPageEntity>>`. `CacheFailure` (existing `Failure` subtype) is used for both parser exceptions and isolate failures.
- **Use case** `GetMushafPage` updates its signature accordingly and is awaited identically.
- **Cubit** folds `Either`:
  - `Left(failure)` → `emit(MushafError(failure.message))`.
  - `Right(entity)` → build spans, cache them, emit `MushafLoaded`.
- All `emit` sites guarded with `if (isClosed) return;` (fast-swipe race fix; covers the long-running `compute()` call resolving after disposal).
- **No silent catches.** If the spans builder throws (e.g., a malformed page), the exception propagates to the cubit and becomes `MushafError`.

---

## 7. Edge Cases

- **Highlight on a not-yet-visited page** — notifier fires but no `MushafText` for that page is mounted; no-op. When the user swipes to it, spans are built from cache and the overlay is applied during `loadPageSync`/`loadPage`.
- **Same ayah on two pages** — both pages highlight while it is current; matches existing behaviour.
- **Rapid swipes past cacheExtent** — old cubits disposed normally; the singleton caches retain entities/spans for fast re-entry.
- **Cache eviction during active highlight** — `MushafSpansCache` eviction does not invalidate the spans list currently held by a live `MushafLoaded` state; the widget continues to render its retained spans by reference until its cubit re-emits.
- **`didHaveMemoryPressure`** — `MushafSpansCache.clear()` + `MushafPageCache.trimAround(current, keep: 5)`. The currently-visible page's cubit still holds its `spans` by reference, so the visible page never blanks out.
- **Theme change** — `MushafPage.didChangeDependencies` detects a `colorScheme` change and notifies live cubits via `cubit.rebuildSpansForTheme(newColorScheme)`. The page-entity cache survives; the spans cache is invalidated for affected entries.
- **Locale change** (Arabic↔English) — `PageView.reverse` already depends on `context.isArabic`; the existing flip stays. Spans are font-only and not localized, so no rebuild required for locale alone.
- **Isolate parse failure** — caught in repo, mapped to `CacheFailure`. The page shows `MushafError(...)` instead of garbage. The page is **not** cached in this case.

---

## 8. Out of Scope

- **Font consolidation** (Approach C). The only change that *eliminates* the glyph-corruption ceiling on 4 GB devices. Deferred by user choice. Document this in the spec so that if users continue to report glyph breaks after this work ships, we have a recorded next step.
- **Audio preload memory accounting** in `PlaybackCubit._preloadNextAyahs`.
- **`Either` migration** for other repositories (surah list, hadith, etc.).
- **DI file relocation** flagged by health-check (item: `mushaf_di.dart` should live at the feature root).
- **`isClosed` guards on `PlaybackCubit`** (separate health-check item).

---

## 9. Testing Strategy

### 9.1 Unit tests

- `MushafPageCache` — LRU order; capacity enforced; eviction listeners fire exactly once per evicted entry; MRU touch on `get`.
- `MushafSpansCache` — wired to page cache's eviction listener so `pageCache` eviction clears the spans entry.
- `MushafRepositoryImpl` — cache hit returns without delegating; cache miss delegates once and stores the result; data-source throw → `Left(CacheFailure)`.
- `AyahTextSpanBuilder.buildBase` — correct span count and order for a fixture page; uses `QCF_P###` font family; no `highlightedStyle`.
- `AyahTextSpanBuilder.buildHighlightOverlay` — given a base list, returns a new list with exactly the matching ayah replaced by a styled span; returns the *same reference* when `currentAyah` is null or absent from the page.
- `MushafCubit` — `loadPageSync` warm-cache emits exactly `[MushafLoaded]`; cold path emits `[MushafLoading, MushafLoaded]`; isolate failure folds to `MushafError`; all emits guarded by `isClosed`.
- `CurrentAyahNotifier` — bridges `PlaybackCubit` ayah stream to `value`; cancels subscription on dispose; deduplicates identical values via `.distinct()`.

### 9.2 Widget tests

- `MushafText` paints a `RichText` with the cubit's prepared spans.
- `ValueListenableBuilder` notification with a non-matching ayah does **not** rebuild the page widget tree beyond the `RichText` paint phase (verified via a `LayoutBuilder` counter or `RepaintBoundary` capture).
- `MushafPageContent` never shows `CircularProgressIndicator` on the warm-cache path.
- `MushafPage` swipe pump: swipe forward then back; data-source `getPage` call counter increments once per unique page only.

### 9.3 Manual on-device validation (load-bearing)

Profile-mode build on a 4 GB Android device. Compare against current `main`:

1. Cold-start → open mushaf → record baseline RSS.
2. Swipe forward 60 pages; record final RSS and any jank observed. Target: no `Loading` flicker on backward swipes.
3. Swipe back to page 1; verify no re-parse (debug counter in data source).
4. Start autoplay on a long page for ≥50 ayahs; verify `MushafText.build` instrumentation fires zero times per tick (only `RichText` paint).
5. Long-session stress: swipe all 604 pages over ~10 minutes; record when (if) glyph corruption occurs. Compare to `main`.
6. Trigger memory pressure: `adb shell am send-trim-memory <PID> RUNNING_CRITICAL`. Confirm caches trim and the app recovers without restart.

### 9.4 No new integration tests

The mushaf has no existing integration harness and adding a full `PageView` swipe-mode integration test is out of scope.

---

## 10. Rollout

Single PR off `feature/001-surah-list`. Behind no feature flag — the changes are internal to the mushaf rendering pipeline and behaviour-preserving for the happy path. Manual on-device validation gate before merging.

---

## 11. Risks

| Risk | Severity | Mitigation |
|------|----------|------------|
| Glyph corruption still occurs on long 4 GB sessions | Medium | Document Approach C as the recorded next step. Memory-pressure trim is our only Dart-side lever. |
| `compute()` isolate startup cost dominates on cold load | Low | Isolate spin-up is ~10 ms; parse is one-shot per page and the result is cached. Net positive. |
| `ValueListenableBuilder` rebuilding even on no-op ticks adds overhead | Low | Rebuild allocates one closure call and returns reference-equal spans → `RenderParagraph` short-circuits relayout. Verified by widget test. |
| `MushafSpansCache` evicts the visible page's spans while in view | Low | Visible `MushafText` retains the spans by reference through `MushafLoaded`; cache eviction does not affect mounted widgets. |
| Theme change races with in-flight `compute()` | Low | `rebuildSpansForTheme` re-runs only on already-loaded entities; in-flight loads complete with the *new* theme captured at emit time. |
| Splitting span builder into `buildBase`/`buildHighlightOverlay` regresses an edge case (e.g., leading-character `ﭐ` marker) | Medium | Unit test the marker is preserved on the highlighted span; test fixtures cover first-ayah-of-surah pages. |
