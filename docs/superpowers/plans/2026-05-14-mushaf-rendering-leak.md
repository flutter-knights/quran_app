# Mushaf Rendering Memory & Performance Fix — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the Loading flicker on swipe-back, stop re-parsing already-visited pages, stop rebuilding the 15-line span list on every playback ayah-tick, and materially delay Skia glyph-atlas exhaustion on 4 GB Android devices — without changing the QCF Madani font rendering.

**Architecture:** Add two LRU caches (`MushafPageCache` for parsed entities, `MushafSpansCache` for prepared `List<InlineSpan>`), move page parsing onto a background isolate via `compute()`, lift highlight delivery onto a `ValueNotifier`-backed `CurrentAyahNotifier` so `MushafText` no longer subscribes to `PlaybackCubit`, wrap each page in `RepaintBoundary`, precache the `SurahHeader` `Image.asset`, and register a `WidgetsBindingObserver` on `MushafPage` to trim caches on `didHaveMemoryPressure`.

**Tech Stack:** Flutter, `flutter_bloc` (Cubit), `get_it` (DI), `dartz` (`Either`), `flutter_test` + `mocktail` + `bloc_test`, `compute()` from `dart:isolate` via `package:flutter/foundation.dart`.

**Spec reference:** `docs/superpowers/specs/2026-05-14-mushaf-rendering-leak-design.md`

---

## File Map

**Will create (lib):**
- `lib/core/errors/failure.dart` — add `CacheFailure` subclass (modify, not create — file exists)
- `lib/features/surah/data/datasources/mushaf_page_cache.dart` — LRU<int, MushafPageEntity>
- `lib/features/surah/data/datasources/mushaf_spans_cache.dart` — LRU<int, List<InlineSpan>> with eviction listener wired to page cache
- `lib/features/surah/data/datasources/mushaf_local_data_source.dart` — refactor `_parseMushafPage` top-level function for `compute()` (refactor existing)
- `lib/features/surah/presentation/utils/current_ayah_notifier.dart` — `ValueNotifier<AyahIdentifier?>` bridge to `PlaybackCubit`

**Will modify (lib):**
- `lib/core/errors/failure.dart`
- `lib/features/surah/data/datasources/mushaf_local_data_source.dart` — remove mutable singleton fields; make `getPage` pure
- `lib/features/surah/data/repositories/mushaf_repo_impl.dart` — return `Either`, consult page cache, parse via `compute()`
- `lib/features/surah/domain/repositories/mushaf_repo.dart` — signature → `Future<Either<Failure, MushafPageEntity>>`
- `lib/features/surah/domain/usecases/get_mushaf_page.dart` — return `Either`
- `lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart` — sealed states; `MushafLoaded` carries `spans`, `normalStyle`, `highlightedStyle`
- `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart` — `loadPageSync`, owns spans, `isClosed` guards, captures `ColorScheme`
- `lib/features/surah/presentation/pages/mushaf/widgets/ayah_text_span_builder.dart` — split into `buildBase` + `buildHighlightOverlay`
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_text.dart` — drop `BlocBuilder<PlaybackCubit>`; use `ValueListenableBuilder` + `RepaintBoundary`
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_layout.dart` — `RepaintBoundary` wrap
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content.dart` — fold `Either`-shaped state; no flicker on warm cache
- `lib/features/surah/presentation/pages/mushaf/widgets/surah_header.dart` — precached static `AssetImage` + `ResizeImage`
- `lib/features/surah/presentation/pages/mushaf/mushaf_pages.dart` — `WidgetsBindingObserver` for memory pressure; explicit `cacheExtent`; `precacheImage` for header
- `lib/features/surah/presentation/pages/mushaf/mushaf_di.dart` — register page cache, spans cache, `CurrentAyahNotifier`
- `lib/features/quran_playback/playback_di.dart` — ensure `PlaybackCubit` is constructable for the notifier (or have `CurrentAyahNotifier` subscribe lazily)

**Will create (test):**
- `test/features/surah/data/datasources/mushaf_page_cache_test.dart`
- `test/features/surah/data/datasources/mushaf_spans_cache_test.dart`
- `test/features/surah/data/repositories/mushaf_repo_impl_test.dart`
- `test/features/surah/presentation/cubit/mushaf_cubit_test.dart`
- `test/features/surah/presentation/utils/current_ayah_notifier_test.dart`
- `test/features/surah/presentation/pages/mushaf/widgets/ayah_text_span_builder_test.dart`
- `test/features/surah/presentation/pages/mushaf/widgets/mushaf_text_test.dart`
- `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content_test.dart`

**Will NOT change:**
- `pubspec.yaml` (no new deps — `compute` is in `flutter/foundation`, all test deps already present)
- The 604 QCF font declarations (out of scope per design)
- Other features (home, hadith, playback rendering, etc.)

---

## Task 1: Add `CacheFailure` to core failures

**Files:**
- Modify: `lib/core/errors/failure.dart`
- Test: none (trivial value class, covered by tests in Task 6)

- [ ] **Step 1: Add the failure subclass**

Open `lib/core/errors/failure.dart` and append at the end of the file (after `LocationPermissionDeniedForeverFailure`):

```dart
class CacheFailure extends Failure {
  const CacheFailure(super.message);
}
```

- [ ] **Step 2: Verify the file still compiles**

Run:

```powershell
dart analyze lib/core/errors/failure.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Commit**

```powershell
git add lib/core/errors/failure.dart
git commit -m "feat(core): add CacheFailure for local cache/parse errors

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 2: `MushafPageCache` — LRU<int, MushafPageEntity>

**Files:**
- Create: `lib/features/surah/data/datasources/mushaf_page_cache.dart`
- Test: `test/features/surah/data/datasources/mushaf_page_cache_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/features/surah/data/datasources/mushaf_page_cache_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_page_cache.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';

MushafPageEntity _entity(int n) => MushafPageEntity(
      pageNumber: n,
      ayahs: const [],
      surahNames: const [],
      surahHeadersIndexes: const [],
      showBasmalaList: const [],
      ayahIdentifiers: const <AyahIdentifier>[],
      basmalaIndexes: const [],
    );

void main() {
  test('get returns null for an absent key', () {
    final cache = MushafPageCache(capacity: 3);
    expect(cache.get(1), isNull);
  });

  test('put then get returns the same instance', () {
    final cache = MushafPageCache(capacity: 3);
    final e = _entity(1);
    cache.put(1, e);
    expect(identical(cache.get(1), e), isTrue);
  });

  test('evicts the least recently used when over capacity', () {
    final cache = MushafPageCache(capacity: 2);
    cache.put(1, _entity(1));
    cache.put(2, _entity(2));
    cache.put(3, _entity(3));
    expect(cache.get(1), isNull); // 1 evicted
    expect(cache.get(2), isNotNull);
    expect(cache.get(3), isNotNull);
  });

  test('get marks an entry as most recently used', () {
    final cache = MushafPageCache(capacity: 2);
    cache.put(1, _entity(1));
    cache.put(2, _entity(2));
    cache.get(1); // touch 1
    cache.put(3, _entity(3)); // evicts 2, not 1
    expect(cache.get(1), isNotNull);
    expect(cache.get(2), isNull);
    expect(cache.get(3), isNotNull);
  });

  test('eviction listener fires with the evicted key', () {
    final cache = MushafPageCache(capacity: 1);
    final evicted = <int>[];
    cache.addEvictionListener(evicted.add);
    cache.put(1, _entity(1));
    cache.put(2, _entity(2)); // evicts 1
    expect(evicted, equals([1]));
  });

  test('trimAround keeps only pages within +/- window of pivot', () {
    final cache = MushafPageCache(capacity: 10);
    for (var i = 1; i <= 10; i++) {
      cache.put(i, _entity(i));
    }
    cache.trimAround(pivot: 5, keep: 5); // keep pages 3..7
    for (var i = 1; i <= 10; i++) {
      final inside = (i - 5).abs() <= 2;
      expect(cache.get(i) != null, inside, reason: 'page $i');
    }
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
flutter test test/features/surah/data/datasources/mushaf_page_cache_test.dart
```

Expected: compile error — `mushaf_page_cache.dart` doesn't exist yet.

- [ ] **Step 3: Implement `MushafPageCache`**

Create `lib/features/surah/data/datasources/mushaf_page_cache.dart`:

```dart
import 'dart:collection';

import '../../domain/entities/mushaf_page_entity.dart';

typedef _EvictionListener = void Function(int pageNumber);

class MushafPageCache {
  MushafPageCache({required this.capacity}) : assert(capacity > 0);

  final int capacity;
  final LinkedHashMap<int, MushafPageEntity> _entries = LinkedHashMap();
  final List<_EvictionListener> _listeners = [];

  MushafPageEntity? get(int pageNumber) {
    final value = _entries.remove(pageNumber);
    if (value == null) return null;
    _entries[pageNumber] = value;
    return value;
  }

  void put(int pageNumber, MushafPageEntity entity) {
    _entries.remove(pageNumber);
    _entries[pageNumber] = entity;
    while (_entries.length > capacity) {
      final oldestKey = _entries.keys.first;
      _entries.remove(oldestKey);
      for (final l in _listeners) {
        l(oldestKey);
      }
    }
  }

  void addEvictionListener(void Function(int pageNumber) listener) {
    _listeners.add(listener);
  }

  void trimAround({required int pivot, required int keep}) {
    assert(keep > 0);
    final radius = (keep - 1) ~/ 2;
    final lo = pivot - radius;
    final hi = pivot + radius;
    final toEvict = _entries.keys
        .where((k) => k < lo || k > hi)
        .toList(growable: false);
    for (final k in toEvict) {
      _entries.remove(k);
      for (final l in _listeners) {
        l(k);
      }
    }
  }

  void clear() {
    final keys = _entries.keys.toList(growable: false);
    _entries.clear();
    for (final k in keys) {
      for (final l in _listeners) {
        l(k);
      }
    }
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```powershell
flutter test test/features/surah/data/datasources/mushaf_page_cache_test.dart
```

Expected: all 6 tests pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/surah/data/datasources/mushaf_page_cache.dart `
        test/features/surah/data/datasources/mushaf_page_cache_test.dart
git commit -m "feat(surah): add MushafPageCache LRU for parsed page entities

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 3: `MushafSpansCache` — LRU<int, List<InlineSpan>> wired to page cache

**Files:**
- Create: `lib/features/surah/data/datasources/mushaf_spans_cache.dart`
- Test: `test/features/surah/data/datasources/mushaf_spans_cache_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/features/surah/data/datasources/mushaf_spans_cache_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_page_cache.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_spans_cache.dart';

List<InlineSpan> _spans(String t) => [TextSpan(text: t)];

void main() {
  late MushafPageCache pageCache;
  late MushafSpansCache spansCache;

  setUp(() {
    pageCache = MushafPageCache(capacity: 3);
    spansCache = MushafSpansCache(capacity: 3, pageCache: pageCache);
  });

  test('put/get round-trips a list by reference', () {
    final s = _spans('a');
    spansCache.put(1, s);
    expect(identical(spansCache.get(1), s), isTrue);
  });

  test('evicts when over its own capacity', () {
    final cache = MushafSpansCache(capacity: 2, pageCache: pageCache);
    cache.put(1, _spans('a'));
    cache.put(2, _spans('b'));
    cache.put(3, _spans('c'));
    expect(cache.get(1), isNull);
    expect(cache.get(2), isNotNull);
    expect(cache.get(3), isNotNull);
  });

  test('removes entry when page cache evicts the matching key', () {
    spansCache.put(1, _spans('a'));
    // Simulate eviction by calling listeners directly via a known path:
    // put 4 items into the page cache to evict page 1.
    // We expose pageCache eviction by directly invoking its eviction path.
    // For this test we drive eviction by adding entries to the (already
    // constructed) page cache then forcing capacity overflow.
    for (var i = 1; i <= 4; i++) {
      pageCache.put(i, _stubEntity(i));
    }
    // page 1 should now be evicted from pageCache (capacity 3),
    // and the spans cache listener should have cleared spans[1].
    expect(spansCache.get(1), isNull);
  });

  test('clear() drops all entries', () {
    spansCache.put(1, _spans('a'));
    spansCache.put(2, _spans('b'));
    spansCache.clear();
    expect(spansCache.get(1), isNull);
    expect(spansCache.get(2), isNull);
  });
}

// Local helper duplicated from Task 2 test (the engineer may read these out
// of order; do not refactor into a shared helpers file in this plan).
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';

MushafPageEntity _stubEntity(int n) => MushafPageEntity(
      pageNumber: n,
      ayahs: const [],
      surahNames: const [],
      surahHeadersIndexes: const [],
      showBasmalaList: const [],
      ayahIdentifiers: const <AyahIdentifier>[],
      basmalaIndexes: const [],
    );
```

Note: the imports placed below `void main()` are syntactically not allowed in Dart. Move them to the top of the file when typing — they're shown here in two blocks for clarity. The correct file layout is: all imports first, then helpers, then `void main()`.

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
flutter test test/features/surah/data/datasources/mushaf_spans_cache_test.dart
```

Expected: compile error — `mushaf_spans_cache.dart` doesn't exist yet.

- [ ] **Step 3: Implement `MushafSpansCache`**

Create `lib/features/surah/data/datasources/mushaf_spans_cache.dart`:

```dart
import 'dart:collection';

import 'package:flutter/material.dart';

import 'mushaf_page_cache.dart';

class MushafSpansCache {
  MushafSpansCache({required this.capacity, required MushafPageCache pageCache})
      : assert(capacity > 0) {
    pageCache.addEvictionListener(_onPageEvicted);
  }

  final int capacity;
  final LinkedHashMap<int, List<InlineSpan>> _entries = LinkedHashMap();

  List<InlineSpan>? get(int pageNumber) {
    final v = _entries.remove(pageNumber);
    if (v == null) return null;
    _entries[pageNumber] = v;
    return v;
  }

  void put(int pageNumber, List<InlineSpan> spans) {
    _entries.remove(pageNumber);
    _entries[pageNumber] = spans;
    while (_entries.length > capacity) {
      _entries.remove(_entries.keys.first);
    }
  }

  void clear() => _entries.clear();

  void _onPageEvicted(int pageNumber) {
    _entries.remove(pageNumber);
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```powershell
flutter test test/features/surah/data/datasources/mushaf_spans_cache_test.dart
```

Expected: all 4 tests pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/surah/data/datasources/mushaf_spans_cache.dart `
        test/features/surah/data/datasources/mushaf_spans_cache_test.dart
git commit -m "feat(surah): add MushafSpansCache wired to page cache eviction

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 4: Make `MushafLocalDataSource.getPage` pure (no mutable singleton fields)

**Files:**
- Modify: `lib/features/surah/data/datasources/mushaf_local_data_source.dart`
- Test: none directly — covered by the repo test in Task 6

- [ ] **Step 1: Refactor the file**

Open `lib/features/surah/data/datasources/mushaf_local_data_source.dart` and replace its full contents with:

```dart
import 'package:quran/line_break.dart';
import 'package:quran/quran.dart' as quran;
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../models/mushaf_page_model.dart';

class MushafLocalDataSource {
  const MushafLocalDataSource();

  MushafPageModel getPage(int pageNumber) {
    final pageData = quran.getPageData(pageNumber);
    final Map<int, int>? linesConfig = lineSymbolsCount[pageNumber];

    var currentLine = 1;
    var symbolsOnCurrentLine = 0;

    final List<String> ayahs = [];
    final List<int> surahHeadersIndexes = [];
    final List<int> basmalaIndexes = [];
    final List<String> surahNames = [];
    final List<bool> surahHasBasmala = [];
    final List<AyahIdentifier> ayahIdentifiers = [];

    for (final block in pageData) {
      final int surah = block['surah'];
      final int start = block['start'];
      final int end = block['end'];
      if (start == 0 && end == 0) {
        surahNames.add(quran.getQcfSurahName(surah));
        surahHeadersIndexes.add(ayahs.length);
        continue;
      }
      if (start == 0) {
        surahNames.add(quran.getQcfSurahName(surah));
        surahHeadersIndexes.add(ayahs.length);
      }

      if (start == 1) {
        final bool hasBasmala = surah != 9 && pageNumber != 1;
        surahHasBasmala.add(hasBasmala);
        if (hasBasmala) basmalaIndexes.add(ayahs.length);
      }

      for (int ayah = start; ayah <= end; ayah++) {
        if (ayah == 0) continue;

        final rawVerse = quran.getVerseQCF(surah, ayah);

        final (verseWithBreaks, nextLine, nextSymbols) = _injectLineBreaks(
          rawVerse,
          linesConfig,
          currentLine,
          symbolsOnCurrentLine,
        );
        currentLine = nextLine;
        symbolsOnCurrentLine = nextSymbols;

        final finalVerse = _preprocessVerse(verseWithBreaks, ayah, start);
        ayahs.add(finalVerse);
        ayahIdentifiers.add(AyahIdentifier(surah: surah, ayah: ayah));
      }
    }

    return MushafPageModel(
      pageNumber: pageNumber,
      ayahs: ayahs,
      surahNames: surahNames,
      surahHeadersIndexes: surahHeadersIndexes,
      basmalaIndexes: basmalaIndexes,
      showBasmalaList: surahHasBasmala,
      ayahIdentifiers: ayahIdentifiers,
    );
  }

  (String, int, int) _injectLineBreaks(
    String verse,
    Map<int, int>? linesConfig,
    int currentLine,
    int symbolsOnCurrentLine,
  ) {
    if (linesConfig == null) {
      return (verse.replaceAll(' ', ''), currentLine, symbolsOnCurrentLine);
    }
    final symbols = verse.trim().split(' ');
    final buffer = StringBuffer();
    var line = currentLine;
    var symbols0nLine = symbolsOnCurrentLine;
    for (var i = 0; i < symbols.length; i++) {
      buffer.write(symbols[i]);
      symbols0nLine++;
      final limit = linesConfig[line];
      if (limit != null && symbols0nLine >= limit) {
        buffer.write('\n');
        line++;
        symbols0nLine = 0;
      }
    }
    return (buffer.toString(), line, symbols0nLine);
  }

  String _preprocessVerse(String verse, int currentAyah, int startAyah) {
    var processed = verse.replaceAll(' ', '');
    if (currentAyah == startAyah && processed.isNotEmpty) {
      processed = '${processed.substring(0, 1)}ﭐ${processed.substring(1)}';
    }
    return processed;
  }
}

/// Top-level helper for `compute()`. Lives next to the data source so the
/// isolate doesn't pull unrelated DI graph.
MushafPageModel parseMushafPageInIsolate(int pageNumber) {
  return const MushafLocalDataSource().getPage(pageNumber);
}
```

- [ ] **Step 2: Verify the file compiles**

Run:

```powershell
dart analyze lib/features/surah/data/datasources/mushaf_local_data_source.dart
```

Expected: `No issues found!`

- [ ] **Step 3: Smoke-test by parsing pages 1 and 100**

Create a temporary scratch file `tmp_test/mushaf_smoke_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_local_data_source.dart';

void main() {
  test('parses page 1 with expected basmala behaviour', () {
    final page = const MushafLocalDataSource().getPage(1);
    expect(page.pageNumber, 1);
    expect(page.ayahs, isNotEmpty);
    expect(page.basmalaIndexes, isEmpty); // page 1 has no basmala
  });

  test('parses page 100 produces consistent output on repeat calls', () {
    final a = const MushafLocalDataSource().getPage(100);
    final b = const MushafLocalDataSource().getPage(100);
    expect(a.ayahs, equals(b.ayahs)); // pure
    expect(a.surahHeadersIndexes, equals(b.surahHeadersIndexes));
  });
}
```

Run:

```powershell
flutter test tmp_test/mushaf_smoke_test.dart
```

Expected: both tests pass. Then delete the scratch file:

```powershell
Remove-Item tmp_test -Recurse -Force
```

- [ ] **Step 4: Commit**

```powershell
git add lib/features/surah/data/datasources/mushaf_local_data_source.dart
git commit -m "refactor(surah): make MushafLocalDataSource pure (no mutable fields)

Parser state moved to locals inside getPage; adds parseMushafPageInIsolate
top-level entry point so the repo can offload parsing via compute().

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 5: Update `MushafRepository` signature to `Either<Failure, MushafPageEntity>`

**Files:**
- Modify: `lib/features/surah/domain/repositories/mushaf_repo.dart`
- Modify: `lib/features/surah/domain/usecases/get_mushaf_page.dart`
- (Repo impl is updated in Task 6; cubit in Task 8 — both compile-broken until then)

- [ ] **Step 1: Update the abstract repository**

Replace `lib/features/surah/domain/repositories/mushaf_repo.dart` with:

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/mushaf_page_entity.dart';

abstract class MushafRepository {
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber);
}
```

- [ ] **Step 2: Update the use case**

Replace `lib/features/surah/domain/usecases/get_mushaf_page.dart` with:

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/mushaf_page_entity.dart';
import '../repositories/mushaf_repo.dart';

class GetMushafPage {
  GetMushafPage(this.repository);

  final MushafRepository repository;

  Future<Either<Failure, MushafPageEntity>> call(int pageNumber) {
    return repository.getPage(pageNumber);
  }
}
```

Note: `UseCase<T, P>` is dropped here because the project's existing `Either`-returning use cases (`PreCachePrayerTimes`, etc.) do not extend it either. Drop is consistent.

- [ ] **Step 3: Verify the domain layer compiles**

Run:

```powershell
dart analyze lib/features/surah/domain
```

Expected: `No issues found!` (repo impl and cubit will be analyzed after Tasks 6 & 8).

- [ ] **Step 4: Do not commit yet**

The repo impl and cubit are still on the old signature and the project does **not** compile end-to-end until Tasks 6 and 8 are done. Defer the commit until the end of Task 8 to keep `main` always green when tasks land in order, and call this out in the bundled commit.

---

## Task 6: `MushafRepositoryImpl` with cache + `compute()` parse

**Files:**
- Modify: `lib/features/surah/data/repositories/mushaf_repo_impl.dart`
- Test: `test/features/surah/data/repositories/mushaf_repo_impl_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/features/surah/data/repositories/mushaf_repo_impl_test.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_page_cache.dart';
import 'package:quran_app/features/surah/data/models/mushaf_page_model.dart';
import 'package:quran_app/features/surah/data/repositories/mushaf_repo_impl.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';

MushafPageModel _entity(int n) => MushafPageModel(
      pageNumber: n,
      ayahs: const ['A'],
      surahNames: const [],
      surahHeadersIndexes: const [],
      showBasmalaList: const [],
      ayahIdentifiers: const <AyahIdentifier>[],
      basmalaIndexes: const [],
    );

class FakeParser {
  int calls = 0;
  bool shouldThrow = false;
  Future<MushafPageModel> parse(int pageNumber) async {
    calls++;
    if (shouldThrow) throw StateError('boom');
    return _entity(pageNumber);
  }
}

void main() {
  late MushafPageCache cache;
  late FakeParser parser;
  late MushafRepositoryImpl repo;

  setUp(() {
    cache = MushafPageCache(capacity: 5);
    parser = FakeParser();
    repo = MushafRepositoryImpl(pageCache: cache, parser: parser.parse);
  });

  test('cache miss: delegates to parser, caches result, returns Right', () async {
    final result = await repo.getPage(7);
    expect(result, isA<Right<Failure, MushafPageEntity>>());
    expect(parser.calls, 1);
    expect(cache.get(7), isNotNull);
  });

  test('cache hit: does not call parser', () async {
    cache.put(7, _entity(7));
    final result = await repo.getPage(7);
    expect(result, isA<Right<Failure, MushafPageEntity>>());
    expect(parser.calls, 0);
  });

  test('parser throw maps to Left(CacheFailure) and does not cache', () async {
    parser.shouldThrow = true;
    final result = await repo.getPage(7);
    expect(result.isLeft(), isTrue);
    result.fold((f) => expect(f, isA<CacheFailure>()), (_) => fail('expected Left'));
    expect(cache.get(7), isNull);
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
flutter test test/features/surah/data/repositories/mushaf_repo_impl_test.dart
```

Expected: compile error — `MushafRepositoryImpl` does not take `pageCache`/`parser` yet.

- [ ] **Step 3: Implement the repo**

Replace `lib/features/surah/data/repositories/mushaf_repo_impl.dart` with:

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';

import '../../../../core/errors/failure.dart';
import '../../domain/entities/mushaf_page_entity.dart';
import '../../domain/repositories/mushaf_repo.dart';
import '../datasources/mushaf_local_data_source.dart';
import '../datasources/mushaf_page_cache.dart';

typedef MushafPageParser = Future<MushafPageEntity> Function(int pageNumber);

class MushafRepositoryImpl implements MushafRepository {
  MushafRepositoryImpl({
    required this.pageCache,
    MushafPageParser? parser,
  }) : _parser = parser ?? _defaultParser;

  final MushafPageCache pageCache;
  final MushafPageParser _parser;

  static Future<MushafPageEntity> _defaultParser(int pageNumber) {
    return compute(parseMushafPageInIsolate, pageNumber);
  }

  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int pageNumber) async {
    final cached = pageCache.get(pageNumber);
    if (cached != null) return Right(cached);
    try {
      final entity = await _parser(pageNumber);
      pageCache.put(pageNumber, entity);
      return Right(entity);
    } catch (e) {
      return Left(CacheFailure('Failed to parse page $pageNumber: $e'));
    }
  }
}
```

The `parser` argument is injectable for tests; production code uses the `compute()` default.

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```powershell
flutter test test/features/surah/data/repositories/mushaf_repo_impl_test.dart
```

Expected: all 3 tests pass.

- [ ] **Step 5: Do not commit yet**

Project still does not compile (mushaf_di.dart constructs `MushafRepositoryImpl(sl())` — the old positional arg). Fixed in Task 12.

---

## Task 7: `CurrentAyahNotifier` — `ValueNotifier<AyahIdentifier?>` bridge

**Files:**
- Create: `lib/features/surah/presentation/utils/current_ayah_notifier.dart`
- Test: `test/features/surah/presentation/utils/current_ayah_notifier_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/features/surah/presentation/utils/current_ayah_notifier_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/presentation/utils/current_ayah_notifier.dart';
import 'package:mocktail/mocktail.dart';

class _FakePlayback extends Mock implements PlaybackCubit {}

void main() {
  late _FakePlayback playback;

  setUp(() {
    playback = _FakePlayback();
  });

  test('initial value is null', () {
    when(() => playback.stream).thenAnswer(
      (_) => const Stream<PlaybackState>.empty(),
    );
    final n = CurrentAyahNotifier(playbackCubit: playback);
    expect(n.value, isNull);
    n.dispose();
  });

  test('forwards distinct currentAyah values from playback stream', () async {
    final controller = StreamController<PlaybackState>();
    addTearDown(controller.close);
    when(() => playback.stream).thenAnswer((_) => controller.stream);

    final n = CurrentAyahNotifier(playbackCubit: playback);
    final seen = <AyahIdentifier?>[];
    n.addListener(() => seen.add(n.value));

    controller.add(const PlaybackState(currentAyah: AyahIdentifier(surah: 1, ayah: 1)));
    await Future<void>.delayed(Duration.zero);
    controller.add(const PlaybackState(currentAyah: AyahIdentifier(surah: 1, ayah: 1))); // dup
    await Future<void>.delayed(Duration.zero);
    controller.add(const PlaybackState(currentAyah: AyahIdentifier(surah: 1, ayah: 2)));
    await Future<void>.delayed(Duration.zero);

    expect(seen.length, 2);
    expect(seen.last, const AyahIdentifier(surah: 1, ayah: 2));
    n.dispose();
  });
}
```

Add `import 'dart:async';` at the top of the file.

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
flutter test test/features/surah/presentation/utils/current_ayah_notifier_test.dart
```

Expected: compile error — `current_ayah_notifier.dart` doesn't exist.

- [ ] **Step 3: Implement `CurrentAyahNotifier`**

Create `lib/features/surah/presentation/utils/current_ayah_notifier.dart`:

```dart
import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';

class CurrentAyahNotifier extends ValueNotifier<AyahIdentifier?> {
  CurrentAyahNotifier({required PlaybackCubit playbackCubit}) : super(null) {
    _sub = playbackCubit.stream
        .map((s) => s.currentAyah)
        .distinct((a, b) => a?.surah == b?.surah && a?.ayah == b?.ayah)
        .listen((ayah) => value = ayah);
  }

  late final StreamSubscription _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
```

`AyahIdentifier` is a domain value object without `operator ==` overrides; equality is by-field via the explicit closure.

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```powershell
flutter test test/features/surah/presentation/utils/current_ayah_notifier_test.dart
```

Expected: both tests pass.

- [ ] **Step 5: Commit**

```powershell
git add lib/features/surah/presentation/utils/current_ayah_notifier.dart `
        test/features/surah/presentation/utils/current_ayah_notifier_test.dart
git commit -m "feat(surah): add CurrentAyahNotifier bridge from PlaybackCubit

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 8: Split `AyahTextSpanBuilder` into `buildBase` + `buildHighlightOverlay`

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_text_span_builder.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/ayah_text_span_builder_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/features/surah/presentation/pages/mushaf/widgets/ayah_text_span_builder_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_text_span_builder.dart';

MushafPageEntity _page() => MushafPageEntity(
      pageNumber: 2,
      ayahs: const ['بسم', 'الله', 'الرحمن'],
      surahNames: const ['الفاتحة'],
      surahHeadersIndexes: const [0],
      basmalaIndexes: const [0],
      showBasmalaList: const [true],
      ayahIdentifiers: const [
        AyahIdentifier(surah: 1, ayah: 1),
        AyahIdentifier(surah: 1, ayah: 2),
        AyahIdentifier(surah: 1, ayah: 3),
      ],
    );

const _normal = TextStyle(color: Colors.black);
const _highlight = TextStyle(color: Colors.red);

void main() {
  testWidgets('buildBase produces header + basmala + N ayah spans', (tester) async {
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
      final spans = AyahTextSpanBuilder.buildBase(
        context: ctx,
        page: _page(),
        pageNumber: 2,
        fontSize: 14,
        lineHeight: 28,
        pageWidth: 300,
        normalStyle: _normal,
      );
      // 1 header (WidgetSpan) + 1 basmala (TextSpan) + 3 ayah TextSpans = 5
      expect(spans, hasLength(5));
      expect(spans.whereType<TextSpan>().every((s) => s.style == _normal || s.style == null || s.style?.color == Colors.black), isTrue);
      return const SizedBox();
    })));
  });

  test('buildHighlightOverlay returns the same instance when currentAyah is null', () {
    final base = <InlineSpan>[const TextSpan(text: 'x')];
    final result = AyahTextSpanBuilder.buildHighlightOverlay(
      baseSpans: base,
      page: _page(),
      currentAyah: null,
      highlightedStyle: _highlight,
      normalStyle: _normal,
    );
    expect(identical(result, base), isTrue);
  });

  test('buildHighlightOverlay returns the same instance when ayah is absent', () {
    final base = <InlineSpan>[const TextSpan(text: 'x')];
    final result = AyahTextSpanBuilder.buildHighlightOverlay(
      baseSpans: base,
      page: _page(),
      currentAyah: const AyahIdentifier(surah: 99, ayah: 99),
      highlightedStyle: _highlight,
      normalStyle: _normal,
    );
    expect(identical(result, base), isTrue);
  });

  testWidgets('buildHighlightOverlay highlights the matching ayah only', (tester) async {
    late List<InlineSpan> base;
    await tester.pumpWidget(MaterialApp(home: Builder(builder: (ctx) {
      base = AyahTextSpanBuilder.buildBase(
        context: ctx,
        page: _page(),
        pageNumber: 2,
        fontSize: 14,
        lineHeight: 28,
        pageWidth: 300,
        normalStyle: _normal,
      );
      return const SizedBox();
    })));
    final highlighted = AyahTextSpanBuilder.buildHighlightOverlay(
      baseSpans: base,
      page: _page(),
      currentAyah: const AyahIdentifier(surah: 1, ayah: 2),
      highlightedStyle: _highlight,
      normalStyle: _normal,
    );
    // Different list reference, same length, exactly one TextSpan styled red.
    expect(identical(highlighted, base), isFalse);
    expect(highlighted, hasLength(base.length));
    final reds = highlighted.whereType<TextSpan>().where((s) => s.style == _highlight).toList();
    expect(reds, hasLength(1));
    expect(reds.single.text, 'الله');
  });
}
```

- [ ] **Step 2: Run the tests to verify they fail**

Run:

```powershell
flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_text_span_builder_test.dart
```

Expected: compile error — `buildBase` and `buildHighlightOverlay` do not exist yet.

- [ ] **Step 3: Reimplement the builder**

Replace `lib/features/surah/presentation/pages/mushaf/widgets/ayah_text_span_builder.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../../../../../config/theme/color_scheme.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../domain/entities/mushaf_page_entity.dart';
import 'basmala_text.dart';
import 'surah_header.dart';

class AyahTextSpanBuilder {
  /// Builds the static span tree for a page. The highlight is applied by
  /// [buildHighlightOverlay] later and does not require rebuilding this list.
  static List<InlineSpan> buildBase({
    required BuildContext context,
    required MushafPageEntity page,
    required int pageNumber,
    required double fontSize,
    required double lineHeight,
    required double pageWidth,
    required TextStyle normalStyle,
  }) {
    final spans = <InlineSpan>[];
    final headerIndexes = page.surahHeadersIndexes.toSet();
    final basmalaIndexes = page.basmalaIndexes.toSet();
    var currentSurahIndex = 0;

    for (int i = 0; i <= page.ayahs.length; i++) {
      if (headerIndexes.contains(i)) {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: SurahHeader(
              name: page.surahNames[currentSurahIndex],
              surahNumber: 1,
              verseCount: 1,
              fontSize: fontSize,
              lineHeight: lineHeight,
            ),
          ),
        );
        currentSurahIndex++;
      }

      if (basmalaIndexes.contains(i)) {
        spans.add(
          BasmalaText(
            fontSize: fontSize,
            lineHeight: lineHeight,
            color: context.colorScheme.onSurface,
          ),
        );
      }

      if (i < page.ayahs.length) {
        spans.add(
          TextSpan(
            locale: const Locale('ar'),
            text: page.ayahs[i],
            style: normalStyle,
          ),
        );
      }
    }

    return spans;
  }

  /// Returns a new list with the matching ayah's TextSpan replaced by a
  /// highlighted copy. If [currentAyah] is null or not present on [page],
  /// returns [baseSpans] by identity so consumers can skip relayout.
  static List<InlineSpan> buildHighlightOverlay({
    required List<InlineSpan> baseSpans,
    required MushafPageEntity page,
    required AyahIdentifier? currentAyah,
    required TextStyle highlightedStyle,
    required TextStyle normalStyle,
  }) {
    if (currentAyah == null) return baseSpans;
    final ayahIndex = page.ayahIdentifiers.indexWhere(
      (a) => a.surah == currentAyah.surah && a.ayah == currentAyah.ayah,
    );
    if (ayahIndex < 0) return baseSpans;

    final headerIndexes = page.surahHeadersIndexes.toSet();
    final basmalaIndexes = page.basmalaIndexes.toSet();

    // Reproduce the iteration from buildBase to translate `ayahIndex` (an
    // index into page.ayahs) into the corresponding index in `baseSpans`.
    var pos = 0;
    for (int i = 0; i <= page.ayahs.length; i++) {
      if (headerIndexes.contains(i)) pos++;
      if (basmalaIndexes.contains(i)) pos++;
      if (i < page.ayahs.length) {
        if (i == ayahIndex) break;
        pos++;
      }
    }

    final original = baseSpans[pos];
    if (original is! TextSpan) return baseSpans; // defensive
    final replacement = TextSpan(
      locale: const Locale('ar'),
      text: original.text,
      style: highlightedStyle,
    );
    final result = List<InlineSpan>.of(baseSpans);
    result[pos] = replacement;
    return result;
  }
}
```

- [ ] **Step 4: Run the tests to verify they pass**

Run:

```powershell
flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_text_span_builder_test.dart
```

Expected: all 4 tests pass.

- [ ] **Step 5: Do not commit yet**

The widget call sites still use the old `build(...)` signature. They'll be fixed in Tasks 9 and 11.

---

## Task 9: `MushafCubit` & `MushafState` — sealed state, owns spans, sync path

**Files:**
- Modify: `lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart`
- Modify: `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`
- Test: `test/features/surah/presentation/cubit/mushaf_cubit_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/features/surah/presentation/cubit/mushaf_cubit_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_page_cache.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_spans_cache.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';

class _FakeUseCase extends Mock implements GetMushafPage {}

MushafPageEntity _entity() => MushafPageEntity(
      pageNumber: 5,
      ayahs: const ['x'],
      surahNames: const [],
      surahHeadersIndexes: const [],
      showBasmalaList: const [],
      ayahIdentifiers: const [AyahIdentifier(surah: 1, ayah: 1)],
      basmalaIndexes: const [],
    );

void main() {
  late MushafPageCache pageCache;
  late MushafSpansCache spansCache;
  late _FakeUseCase useCase;

  setUp(() {
    pageCache = MushafPageCache(capacity: 10);
    spansCache = MushafSpansCache(capacity: 10, pageCache: pageCache);
    useCase = _FakeUseCase();
  });

  group('cold load', () {
    blocTest<MushafCubit, MushafState>(
      'emits [MushafLoading, MushafLoaded] when use case returns Right',
      build: () => MushafCubit(
        useCase: useCase,
        pageCache: pageCache,
        spansCache: spansCache,
      ),
      setUp: () {
        when(() => useCase.call(5))
            .thenAnswer((_) async => Right(_entity()));
      },
      act: (c) => c.loadPage(
        pageNumber: 5,
        colorScheme: const ColorScheme.light(),
        fontSize: 14,
        lineHeight: 28,
        pageWidth: 300,
        builderContext: null,
      ),
      expect: () => [
        isA<MushafLoading>(),
        isA<MushafLoaded>(),
      ],
    );

    blocTest<MushafCubit, MushafState>(
      'emits [MushafLoading, MushafError] when use case returns Left',
      build: () => MushafCubit(
        useCase: useCase,
        pageCache: pageCache,
        spansCache: spansCache,
      ),
      setUp: () {
        when(() => useCase.call(5))
            .thenAnswer((_) async => const Left(CacheFailure('nope')));
      },
      act: (c) => c.loadPage(
        pageNumber: 5,
        colorScheme: const ColorScheme.light(),
        fontSize: 14,
        lineHeight: 28,
        pageWidth: 300,
        builderContext: null,
      ),
      expect: () => [
        isA<MushafLoading>(),
        isA<MushafError>().having((s) => s.message, 'message', 'nope'),
      ],
    );
  });

  test('loadPageSync returns true and emits only Loaded on warm caches', () async {
    pageCache.put(5, _entity());
    // Pre-populate spans cache as well to simulate full warm path.
    spansCache.put(5, <InlineSpan>[const TextSpan(text: 'x')]);

    final cubit = MushafCubit(
      useCase: useCase,
      pageCache: pageCache,
      spansCache: spansCache,
    );
    final emitted = <MushafState>[];
    final sub = cubit.stream.listen(emitted.add);

    final hit = cubit.loadPageSync(
      pageNumber: 5,
      colorScheme: const ColorScheme.light(),
      fontSize: 14,
      lineHeight: 28,
      pageWidth: 300,
      builderContext: null,
    );
    await Future<void>.delayed(Duration.zero);

    expect(hit, isTrue);
    expect(emitted, hasLength(1));
    expect(emitted.single, isA<MushafLoaded>());

    await sub.cancel();
    await cubit.close();
  });

  test('does not emit after close (isClosed guard)', () async {
    when(() => useCase.call(5)).thenAnswer((_) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return Right(_entity());
    });
    final cubit = MushafCubit(
      useCase: useCase,
      pageCache: pageCache,
      spansCache: spansCache,
    );
    // Fire-and-forget then close before the future resolves.
    unawaited(cubit.loadPage(
      pageNumber: 5,
      colorScheme: const ColorScheme.light(),
      fontSize: 14,
      lineHeight: 28,
      pageWidth: 300,
      builderContext: null,
    ));
    await cubit.close();
    await Future<void>.delayed(const Duration(milliseconds: 100));
    // No assertion needed beyond no thrown StateError; reaching here passes.
    expect(true, isTrue);
  });
}
```

Add `import 'dart:async';` to use `unawaited`.

- [ ] **Step 2: Replace `mushaf_state.dart`**

Replace `lib/features/surah/presentation/cubit/mushaf/mushaf_state.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../../domain/entities/mushaf_page_entity.dart';

sealed class MushafState {
  const MushafState();
}

final class MushafInitial extends MushafState {
  const MushafInitial();
}

final class MushafLoading extends MushafState {
  const MushafLoading();
}

final class MushafError extends MushafState {
  const MushafError(this.message);
  final String message;
}

final class MushafLoaded extends MushafState {
  const MushafLoaded({
    required this.page,
    required this.spans,
    required this.normalStyle,
    required this.highlightedStyle,
    required this.pageWidth,
    required this.fontSize,
    required this.lineHeight,
  });

  final MushafPageEntity page;
  final List<InlineSpan> spans;
  final TextStyle normalStyle;
  final TextStyle highlightedStyle;
  final double pageWidth;
  final double fontSize;
  final double lineHeight;
}
```

- [ ] **Step 3: Replace `mushaf_cubit.dart`**

Replace `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/datasources/mushaf_page_cache.dart';
import '../../../data/datasources/mushaf_spans_cache.dart';
import '../../../domain/entities/mushaf_page_entity.dart';
import '../../../domain/usecases/get_mushaf_page.dart';
import '../../pages/mushaf/widgets/ayah_text_span_builder.dart';
import 'mushaf_state.dart';

class MushafCubit extends Cubit<MushafState> {
  MushafCubit({
    required this.useCase,
    required this.pageCache,
    required this.spansCache,
  }) : super(const MushafInitial());

  final GetMushafPage useCase;
  final MushafPageCache pageCache;
  final MushafSpansCache spansCache;

  /// Synchronous warm-path load. Returns true if both caches hit and a
  /// MushafLoaded was emitted in this microtask. Returns false otherwise;
  /// callers should then await [loadPage].
  bool loadPageSync({
    required int pageNumber,
    required ColorScheme colorScheme,
    required double fontSize,
    required double lineHeight,
    required double pageWidth,
    required BuildContext? builderContext,
  }) {
    final entity = pageCache.get(pageNumber);
    final spans = spansCache.get(pageNumber);
    if (entity == null || spans == null || builderContext == null) {
      // Spans cache requires a BuildContext to compose; if we have entity
      // but no spans and no context, fall through to the async path.
      if (entity != null && spans == null && builderContext != null) {
        return _emitLoadedFromEntity(
          entity: entity,
          colorScheme: colorScheme,
          fontSize: fontSize,
          lineHeight: lineHeight,
          pageWidth: pageWidth,
          builderContext: builderContext,
          pageNumber: pageNumber,
        );
      }
      if (entity != null && spans != null) {
        // We can compose from cached spans without context.
        return _emitLoadedWithCachedSpans(
          entity: entity,
          spans: spans,
          colorScheme: colorScheme,
          fontSize: fontSize,
          lineHeight: lineHeight,
          pageWidth: pageWidth,
          pageNumber: pageNumber,
        );
      }
      return false;
    }
    return _emitLoadedWithCachedSpans(
      entity: entity,
      spans: spans,
      colorScheme: colorScheme,
      fontSize: fontSize,
      lineHeight: lineHeight,
      pageWidth: pageWidth,
      pageNumber: pageNumber,
    );
  }

  Future<void> loadPage({
    required int pageNumber,
    required ColorScheme colorScheme,
    required double fontSize,
    required double lineHeight,
    required double pageWidth,
    required BuildContext? builderContext,
  }) async {
    if (isClosed) return;
    emit(const MushafLoading());
    final result = await useCase.call(pageNumber);
    if (isClosed) return;
    result.fold(
      (failure) => emit(MushafError(failure.message)),
      (entity) {
        if (builderContext == null) {
          // Cannot build spans without a context for the SurahHeader image.
          // Fall back to a minimal loaded state with an empty list — the
          // widget tree will rebuild once didChangeDependencies fires with
          // a valid context in the next frame.
          emit(MushafLoaded(
            page: entity,
            spans: const <InlineSpan>[],
            normalStyle: _normalStyle(colorScheme, fontSize, lineHeight, pageNumber),
            highlightedStyle: _highlightedStyle(colorScheme, fontSize, lineHeight, pageNumber),
            pageWidth: pageWidth,
            fontSize: fontSize,
            lineHeight: lineHeight,
          ));
          return;
        }
        _emitLoadedFromEntity(
          entity: entity,
          colorScheme: colorScheme,
          fontSize: fontSize,
          lineHeight: lineHeight,
          pageWidth: pageWidth,
          builderContext: builderContext,
          pageNumber: pageNumber,
        );
      },
    );
  }

  bool _emitLoadedFromEntity({
    required MushafPageEntity entity,
    required ColorScheme colorScheme,
    required double fontSize,
    required double lineHeight,
    required double pageWidth,
    required BuildContext builderContext,
    required int pageNumber,
  }) {
    if (isClosed) return false;
    final normalStyle = _normalStyle(colorScheme, fontSize, lineHeight, pageNumber);
    final spans = AyahTextSpanBuilder.buildBase(
      context: builderContext,
      page: entity,
      pageNumber: pageNumber,
      fontSize: fontSize,
      lineHeight: lineHeight,
      pageWidth: pageWidth,
      normalStyle: normalStyle,
    );
    spansCache.put(pageNumber, spans);
    emit(MushafLoaded(
      page: entity,
      spans: spans,
      normalStyle: normalStyle,
      highlightedStyle: _highlightedStyle(colorScheme, fontSize, lineHeight, pageNumber),
      pageWidth: pageWidth,
      fontSize: fontSize,
      lineHeight: lineHeight,
    ));
    return true;
  }

  bool _emitLoadedWithCachedSpans({
    required MushafPageEntity entity,
    required List<InlineSpan> spans,
    required ColorScheme colorScheme,
    required double fontSize,
    required double lineHeight,
    required double pageWidth,
    required int pageNumber,
  }) {
    if (isClosed) return false;
    emit(MushafLoaded(
      page: entity,
      spans: spans,
      normalStyle: _normalStyle(colorScheme, fontSize, lineHeight, pageNumber),
      highlightedStyle: _highlightedStyle(colorScheme, fontSize, lineHeight, pageNumber),
      pageWidth: pageWidth,
      fontSize: fontSize,
      lineHeight: lineHeight,
    ));
    return true;
  }

  TextStyle _normalStyle(
    ColorScheme cs,
    double fontSize,
    double lineHeight,
    int pageNumber,
  ) =>
      TextStyle(
        fontFamily: 'QCF_P${pageNumber.toString().padLeft(3, '0')}',
        fontSize: fontSize,
        height: lineHeight / fontSize,
        color: cs.onSurface,
      );

  TextStyle _highlightedStyle(
    ColorScheme cs,
    double fontSize,
    double lineHeight,
    int pageNumber,
  ) =>
      _normalStyle(cs, fontSize, lineHeight, pageNumber).copyWith(
        color: cs.onPrimary,
        backgroundColor: cs.primary,
      );
}
```

Note: cubits must not retain `BuildContext` across async gaps. The cubit accepts a `BuildContext?` only to build spans synchronously; it never stores it.

- [ ] **Step 4: Run the cubit tests to verify they pass**

Run:

```powershell
flutter test test/features/surah/presentation/cubit/mushaf_cubit_test.dart
```

Expected: 4 tests pass. (Tests pass a null `builderContext`; the cold-load test asserts `MushafLoaded` is still emitted with an empty spans list as a fallback. The widget will refill spans on first `didChangeDependencies` — covered by Task 11.)

- [ ] **Step 5: Do not commit yet**

`mushaf_page_content.dart` and `mushaf_text.dart` still depend on the old state shape. Fixed in Tasks 10 and 11.

---

## Task 10: `MushafPageContent` — fold the new state shape

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content_test.dart`

- [ ] **Step 1: Write the failing tests**

Create `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content.dart';

class _StubCubit extends Cubit<MushafState> {
  _StubCubit(super.initial);
}

MushafPageEntity _entity() => MushafPageEntity(
      pageNumber: 5,
      ayahs: const [],
      surahNames: const [],
      surahHeadersIndexes: const [],
      basmalaIndexes: const [],
      showBasmalaList: const [],
      ayahIdentifiers: const <AyahIdentifier>[],
    );

void main() {
  testWidgets('renders CircularProgressIndicator on MushafLoading', (tester) async {
    final cubit = _StubCubit(const MushafLoading());
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<MushafCubit>.value(
        value: cubit as MushafCubit,
        child: const MushafPageContent(pageNumber: 5),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
  });

  testWidgets('renders error text on MushafError', (tester) async {
    final cubit = _StubCubit(const MushafError('oh no'));
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<MushafCubit>.value(
        value: cubit as MushafCubit,
        child: const MushafPageContent(pageNumber: 5),
      ),
    ));
    expect(find.text('oh no'), findsOneWidget);
  });

  testWidgets('renders MushafLayout on MushafLoaded with empty spans', (tester) async {
    final cubit = _StubCubit(MushafLoaded(
      page: _entity(),
      spans: const <InlineSpan>[],
      normalStyle: const TextStyle(),
      highlightedStyle: const TextStyle(),
      pageWidth: 300,
      fontSize: 14,
      lineHeight: 28,
    ));
    await tester.pumpWidget(MaterialApp(
      home: BlocProvider<MushafCubit>.value(
        value: cubit as MushafCubit,
        child: const MushafPageContent(pageNumber: 5),
      ),
    ));
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
```

The cast `_StubCubit as MushafCubit` is unsound, so we use a different approach: replace `_StubCubit` with a real `MushafCubit` that emits a seeded state. For brevity here, use a real cubit by wiring a fake use case:

```dart
// Replace the _StubCubit-based helpers with:
import 'package:dartz/dartz.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_page_cache.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_spans_cache.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';

class _FakeUseCase extends Mock implements GetMushafPage {}

MushafCubit _seededCubit(MushafState seed) {
  final pageCache = MushafPageCache(capacity: 1);
  final spansCache = MushafSpansCache(capacity: 1, pageCache: pageCache);
  final useCase = _FakeUseCase();
  when(() => useCase.call(any())).thenAnswer((_) async => Right(_entity()));
  final cubit = MushafCubit(
    useCase: useCase,
    pageCache: pageCache,
    spansCache: spansCache,
  );
  // Seed by emitting via a tiny helper subclass; easier: use a stream
  // controller. Simplest acceptable path: expose a @visibleForTesting
  // `seedForTest` method on the cubit. Add it now (also useful for
  // page-content tests).
  cubit.seedForTest(seed);
  return cubit;
}
```

Add to `mushaf_cubit.dart`:

```dart
@visibleForTesting
void seedForTest(MushafState state) {
  if (!isClosed) emit(state);
}
```

(Re-import `package:flutter/foundation.dart` for the annotation.)

- [ ] **Step 2: Update `MushafPageContent`**

Replace `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';
import 'mushaf_layout.dart';

class MushafPageContent extends StatelessWidget {
  const MushafPageContent({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MushafCubit, MushafState>(
      builder: (context, state) {
        return switch (state) {
          MushafInitial() => const SizedBox(),
          MushafLoading() => const Center(child: CircularProgressIndicator()),
          MushafError(:final message) => Center(child: Text(message)),
          MushafLoaded() => MushafLayout(pageNumber: pageNumber, loaded: state),
        };
      },
    );
  }
}
```

- [ ] **Step 3: Run the page-content tests**

Run:

```powershell
flutter test test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content_test.dart
```

Expected: all 3 tests pass.

- [ ] **Step 4: Do not commit yet**

`MushafLayout` still expects an `entity` parameter (old shape) — fixed in Task 11.

---

## Task 11: `MushafLayout` & `MushafText` — RepaintBoundary + ValueListenableBuilder

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_layout.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_text.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/mushaf_text_test.dart`

- [ ] **Step 1: Replace `mushaf_layout.dart`**

Replace `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_layout.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../../cubit/mushaf/mushaf_state.dart';
import 'mushaf_text.dart';

class MushafLayout extends StatelessWidget {
  const MushafLayout({
    super.key,
    required this.pageNumber,
    required this.loaded,
  });

  final int pageNumber;
  final MushafLoaded loaded;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Expanded(
          child: Center(
            child: AspectRatio(
              aspectRatio: 1 / 1.82,
              child: RepaintBoundary(
                child: MushafText(loaded: loaded, pageNumber: pageNumber),
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(pageNumber.toString()),
      ],
    );
  }
}
```

The dynamic-sized `pageWidth`/`fontSize`/`lineHeight` from the previous `LayoutBuilder` is replaced by values **already captured into `MushafLoaded`** when the cubit emitted. If the layout constraints change (orientation, resize) the cubit will re-emit (driven by `didChangeDependencies` in `MushafPage`).

- [ ] **Step 2: Write the failing test for `MushafText`**

Create `test/features/surah/presentation/pages/mushaf/widgets/mushaf_text_test.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get_it/get_it.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_text.dart';
import 'package:quran_app/features/surah/presentation/utils/current_ayah_notifier.dart';

class _StubNotifier extends ValueNotifier<AyahIdentifier?> {
  _StubNotifier() : super(null);
}

void main() {
  late _StubNotifier notifier;

  setUp(() {
    notifier = _StubNotifier();
    if (sl.isRegistered<CurrentAyahNotifier>()) {
      sl.unregister<CurrentAyahNotifier>();
    }
    sl.registerSingleton<CurrentAyahNotifier>(
      _AsCurrentAyahNotifier(notifier) as CurrentAyahNotifier,
    );
  });

  tearDown(() {
    if (sl.isRegistered<CurrentAyahNotifier>()) {
      sl.unregister<CurrentAyahNotifier>();
    }
  });

  testWidgets('renders RichText with the loaded spans', (tester) async {
    final loaded = MushafLoaded(
      page: MushafPageEntity(
        pageNumber: 2,
        ayahs: const ['ayah'],
        surahNames: const [],
        surahHeadersIndexes: const [],
        basmalaIndexes: const [],
        showBasmalaList: const [],
        ayahIdentifiers: const [AyahIdentifier(surah: 1, ayah: 1)],
      ),
      spans: const [TextSpan(text: 'ayah')],
      normalStyle: const TextStyle(),
      highlightedStyle: const TextStyle(),
      pageWidth: 300,
      fontSize: 14,
      lineHeight: 28,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MushafText(loaded: loaded, pageNumber: 2)),
    ));
    expect(find.byType(RichText), findsWidgets);
    expect(find.byType(RepaintBoundary), findsWidgets);
  });
}
```

Note: the `_AsCurrentAyahNotifier(notifier) as CurrentAyahNotifier` cast won't compile. The test instead must register a real `CurrentAyahNotifier` with a fake `PlaybackCubit`. Replace the stub above with a real one:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';

class _FakePlaybackCubit extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlaybackCubit() : super(const PlaybackState());
  @override
  noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

// In setUp:
sl.registerSingleton<CurrentAyahNotifier>(
  CurrentAyahNotifier(playbackCubit: _FakePlaybackCubit()),
);
```

This compiles because `PlaybackCubit` is a class (not a sealed interface) and `Cubit<PlaybackState>` plus `implements PlaybackCubit` works because `noSuchMethod` covers the unused methods.

- [ ] **Step 3: Replace `mushaf_text.dart`**

Replace `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_text.dart` with:

```dart
import 'package:flutter/material.dart';

import '../../../../../../core/di/dependency_injection.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../cubit/mushaf/mushaf_state.dart';
import '../../../utils/current_ayah_notifier.dart';
import 'ayah_text_span_builder.dart';

class MushafText extends StatelessWidget {
  const MushafText({super.key, required this.loaded, required this.pageNumber});

  final MushafLoaded loaded;
  final int pageNumber;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AyahIdentifier?>(
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
          width: loaded.pageWidth,
          child: RichText(
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            maxLines: 15,
            overflow: TextOverflow.clip,
            text: TextSpan(children: spans),
          ),
        );
      },
    );
  }
}
```

- [ ] **Step 4: Run the widget tests**

Run:

```powershell
flutter test test/features/surah/presentation/pages/mushaf/widgets/mushaf_text_test.dart
```

Expected: 1 test passes.

- [ ] **Step 5: Do not commit yet**

`MushafPage` still constructs cubits and `MushafLayout` with the old shapes — fixed in Tasks 12 and 13.

---

## Task 12: `mushaf_di.dart` — register page cache, spans cache, notifier

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_di.dart`

- [ ] **Step 1: Replace the DI file**

Replace `lib/features/surah/presentation/pages/mushaf/mushaf_di.dart` with:

```dart
import 'package:quran_app/core/di/dependency_injection.dart';

import '../../../../../features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../data/datasources/mushaf_local_data_source.dart';
import '../../../data/datasources/mushaf_page_cache.dart';
import '../../../data/datasources/mushaf_spans_cache.dart';
import '../../../data/repositories/mushaf_repo_impl.dart';
import '../../../domain/repositories/mushaf_repo.dart';
import '../../../domain/usecases/get_mushaf_page.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';
import '../../utils/current_ayah_notifier.dart';

void initMushaf() {
  sl.registerLazySingleton<MushafLocalDataSource>(
    () => const MushafLocalDataSource(),
  );

  sl.registerLazySingleton<MushafPageCache>(
    () => MushafPageCache(capacity: 30),
  );
  sl.registerLazySingleton<MushafSpansCache>(
    () => MushafSpansCache(capacity: 30, pageCache: sl()),
  );

  sl.registerLazySingleton<MushafRepository>(
    () => MushafRepositoryImpl(pageCache: sl()),
  );

  sl.registerLazySingleton(() => GetMushafPage(sl()));

  sl.registerLazySingleton<CurrentAyahNotifier>(
    () => CurrentAyahNotifier(playbackCubit: sl<PlaybackCubit>()),
  );

  sl.registerFactory(
    () => MushafCubit(useCase: sl(), pageCache: sl(), spansCache: sl()),
  );
}
```

- [ ] **Step 2: Confirm `PlaybackCubit` is registered before `CurrentAyahNotifier` is resolved**

Open `lib/features/quran_playback/playback_di.dart` and confirm it registers `PlaybackCubit` as a singleton (it currently does — `LazySingleton`). If it is registered as `factory`, change it to `LazySingleton` so multiple `CurrentAyahNotifier` reads receive the same cubit. **Check by reading the file**, then leave as-is if it's already lazy-singleton.

```powershell
Get-Content lib/features/quran_playback/playback_di.dart
```

Expected to contain `registerLazySingleton<PlaybackCubit>` (or equivalent). If it shows `registerFactory<PlaybackCubit>`, edit it to `registerLazySingleton<PlaybackCubit>` in place — playback is conceptually app-wide and should not be re-instantiated.

- [ ] **Step 3: Run analyzer across `lib/`**

Run:

```powershell
dart analyze lib
```

Expected: `No issues found!` (compile-time errors in MushafPage will be fixed in Task 13.)

If you see `MushafPage` errors, ignore them for now and continue to Task 13.

---

## Task 13: `MushafPage` — cubit wiring, precache header, memory-pressure observer

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_pages.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/surah_header.dart`

- [ ] **Step 1: Precache header image and add a const provider**

Replace `lib/features/surah/presentation/pages/mushaf/widgets/surah_header.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:quran_app/core/constants/device_size_info.dart';

import '../../../../../../config/theme/color_scheme.dart';

const AssetImage kSurahHeaderImage = AssetImage('assets/images/header.png');

class SurahHeader extends StatelessWidget {
  const SurahHeader({
    super.key,
    required this.name,
    required this.verseCount,
    required this.surahNumber,
    required this.fontSize,
    required this.lineHeight,
  });

  final String name;
  final int verseCount;
  final int surahNumber;
  final double fontSize;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final width = context.width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image(
            image: ResizeImage(kSurahHeaderImage, width: width.toInt()),
            color: context.colorScheme.onSurface,
            colorBlendMode: BlendMode.srcIn,
            fit: BoxFit.fill,
            gaplessPlayback: true,
          ),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Gap(6),
                Text(
                  name,
                  locale: const Locale('ar'),
                  style: TextStyle(
                    fontFamily: 'QCF_P000',
                    fontSize: fontSize * 1.4,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Replace `mushaf_pages.dart`**

Replace `lib/features/surah/presentation/pages/mushaf/mushaf_pages.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_page_cache.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_spans_cache.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/surah_header.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../../core/di/dependency_injection.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';

class MushafPage extends StatefulWidget {
  const MushafPage({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage>
    with WidgetsBindingObserver {
  late final PageController _pageController;
  bool _precachedHeader = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _pageController = PageController(initialPage: widget.pageNumber - 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precachedHeader) {
      precacheImage(kSurahHeaderImage, context);
      _precachedHeader = true;
    }
  }

  @override
  void didHaveMemoryPressure() {
    sl<MushafSpansCache>().clear();
    final current =
        (_pageController.page ?? _pageController.initialPage).round() + 1;
    sl<MushafPageCache>().trimAround(pivot: current, keep: 5);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final pageWidth = mediaSize.width;
    final fontSize = pageWidth / 15 * 0.9;
    final lineHeight = pageWidth / 15 * 1.8;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: BlocListener<PlaybackCubit, PlaybackState>(
        listenWhen: (p, c) => p.currentAyah != c.currentAyah,
        listener: (context, state) {
          final cubit = context.read<PlaybackCubit>();
          final targetPage = cubit.getPageForCurrentAyah();
          if (targetPage == null) return;
          if (!_pageController.hasClients) return;
          final currentIndex =
              (_pageController.page ?? _pageController.initialPage).round();
          final targetIndex = targetPage - 1;
          if (currentIndex != targetIndex) {
            _pageController.animateToPage(
              targetIndex,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
          }
        },
        child: PageView.builder(
          controller: _pageController,
          reverse: context.isArabic ? false : true,
          itemCount: 604,
          allowImplicitScrolling: false,
          itemBuilder: (context, index) {
            final pageNumber = index + 1;
            return BlocProvider<MushafCubit>(
              create: (_) {
                final cubit = sl<MushafCubit>();
                final hit = cubit.loadPageSync(
                  pageNumber: pageNumber,
                  colorScheme: colorScheme,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                  pageWidth: pageWidth,
                  builderContext: context,
                );
                if (!hit) {
                  cubit.loadPage(
                    pageNumber: pageNumber,
                    colorScheme: colorScheme,
                    fontSize: fontSize,
                    lineHeight: lineHeight,
                    pageWidth: pageWidth,
                    builderContext: context,
                  );
                }
                return cubit;
              },
              child: MushafPageContent(pageNumber: pageNumber),
            );
          },
        ),
      ),
      floatingActionButton: _FabColumn(controller: _pageController),
    );
  }
}

class _FabColumn extends StatelessWidget {
  const _FabColumn({required this.controller});

  final PageController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'autoplay_page',
          tooltip: 'Autoplay this page',
          onPressed: () {
            final currentIndex =
                (controller.page ?? controller.initialPage).round();
            context.read<PlaybackCubit>().autoPlayPage(currentIndex + 1);
          },
          child: const Icon(Icons.play_arrow),
        ),
        const SizedBox(height: 8),
        BlocBuilder<PlaybackCubit, PlaybackState>(
          buildWhen: (p, c) => p.isPlaying != c.isPlaying,
          builder: (context, state) {
            return FloatingActionButton(
              heroTag: 'pause_playback',
              tooltip: state.isPlaying ? 'Pause playback' : 'Resume playback',
              onPressed: () {
                final cubit = context.read<PlaybackCubit>();
                if (state.isPlaying) {
                  cubit.pause();
                } else {
                  cubit.resume();
                }
              },
              child: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
            );
          },
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'stop_playback',
          tooltip: 'Stop playback',
          onPressed: () => context.read<PlaybackCubit>().stop(),
          child: const Icon(Icons.stop),
        ),
      ],
    );
  }
}
```

- [ ] **Step 3: Run the analyzer across `lib/`**

Run:

```powershell
dart analyze lib
```

Expected: `No issues found!`

- [ ] **Step 4: Run all tests**

Run:

```powershell
flutter test
```

Expected: all existing tests still pass, plus the new ones from Tasks 2, 3, 6, 7, 8, 9, 10, 11.

- [ ] **Step 5: Commit everything since Task 5**

```powershell
git add lib test
git commit -m "feat(surah): rework mushaf rendering for memory & swipe performance

- MushafRepository returns Either<Failure, MushafPageEntity>
- MushafPageCache + MushafSpansCache (LRU singletons, 30 entries) avoid
  re-parsing and re-building the span tree on swipe-back
- Page parsing offloaded to a background isolate via compute()
- AyahTextSpanBuilder split: buildBase (static) + buildHighlightOverlay
  (returns same list by identity when the highlighted ayah is not on the page)
- CurrentAyahNotifier replaces the per-page BlocBuilder<PlaybackCubit>;
  MushafText now uses ValueListenableBuilder so playback ticks don't rebuild
  off-page widgets
- MushafLayout wraps the page in RepaintBoundary
- MushafPage observes didHaveMemoryPressure and trims caches around the
  current page (keeps 5), giving low-RAM devices a recovery path before
  Skia's glyph atlas exhausts and corrupts rendering
- SurahHeader precaches its asset image and uses ResizeImage

Spec: docs/superpowers/specs/2026-05-14-mushaf-rendering-leak-design.md

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Task 14: Manual on-device validation

**Files:** none (manual checklist)

Run a profile-mode build on a 4 GB Android device and compare to `main`. This is the load-bearing validation — unit tests confirm behaviour but not glyph-atlas headroom.

- [ ] **Step 1: Build the profile APK**

Run:

```powershell
flutter build apk --profile
```

Expected output: APK at `build/app/outputs/flutter-apk/app-profile.apk`.

- [ ] **Step 2: Install on a 4 GB Android device**

Run (device connected via USB, USB debugging on):

```powershell
adb install -r build/app/outputs/flutter-apk/app-profile.apk
```

Note the device's PID after launch:

```powershell
adb shell pidof com.example.quran_app
```

(Adjust package name if different — check `android/app/build.gradle`.)

- [ ] **Step 3: Baseline RSS check**

```powershell
adb shell dumpsys meminfo <PID> | findstr "TOTAL"
```

Record the value.

- [ ] **Step 4: Swipe-forward stress (60 pages)**

Open the mushaf, then swipe forward through 60 pages at a comfortable reading pace. Re-run the `dumpsys meminfo` command. Record:
- Final RSS.
- Whether any swipe-back showed a Loading spinner. **Target: zero spinners on backward swipes** after Task 13.

- [ ] **Step 5: No-reparse check**

Swipe back to page 1. Open `lib/features/surah/data/datasources/mushaf_local_data_source.dart` and add a temporary `debugPrint('getPage($pageNumber)');` at the top of `getPage` (revert after this test). Watch `adb logcat -s flutter` while swiping; each page should print **at most once** per session.

Revert the debugPrint:

```powershell
git checkout lib/features/surah/data/datasources/mushaf_local_data_source.dart
```

- [ ] **Step 6: Playback rebuild check**

Add a temporary `debugPrint('MushafText.build $pageNumber');` at the top of `MushafText.build`. Start autoplay and observe `adb logcat -s flutter` for 50 ayahs. **Target: the print fires only on page swipes, not on ayah ticks.**

Revert:

```powershell
git checkout lib/features/surah/presentation/pages/mushaf/widgets/mushaf_text.dart
```

- [ ] **Step 7: Long-session glyph-corruption stress**

Swipe through all 604 pages over ~10 minutes. Record:
- Page number (if any) at which glyphs begin to render incorrectly.
- Compare to baseline by running the same flow on `main` (checkout `main`, build profile APK, repeat). The target is a meaningfully later wall — eliminating it requires Approach C, out of scope.

- [ ] **Step 8: Memory-pressure recovery**

While the app is foregrounded and showing the mushaf, run:

```powershell
adb shell am send-trim-memory <PID> RUNNING_CRITICAL
```

Confirm the app does **not** crash, the current page still renders, and subsequent swipes still work. (`MushafSpansCache` clears and `MushafPageCache` trims to the 5 pages around the current index.)

- [ ] **Step 9: Document results**

Append a short results note to the spec document:

```powershell
notepad docs/superpowers/specs/2026-05-14-mushaf-rendering-leak-design.md
```

Add a final section "Validation Results — <date>" listing:
- Pre/post baseline RSS after 60 swipes
- Pre/post glyph-corruption page count
- Memory-pressure recovery: pass/fail

Commit:

```powershell
git add docs/superpowers/specs/2026-05-14-mushaf-rendering-leak-design.md
git commit -m "docs(mushaf): record on-device validation results

Co-Authored-By: Claude Opus 4.7 <noreply@anthropic.com>"
```

---

## Self-Review Summary

- **Spec coverage:** every section in the spec maps to a task — caches (T2, T3), pure data source (T4), Either-shaped repo + use case (T5, T6), notifier (T7), span builder split (T8), cubit/state with sync path & isClosed guards (T9), no-flicker `MushafPageContent` (T10), `MushafText` + `RepaintBoundary` (T11), DI (T12), `MushafPage` + memory-pressure trim + precached header (T13), manual stress (T14).
- **Placeholders:** none — every code change appears inline with full content.
- **Type consistency:** `MushafLoaded` carries `(page, spans, normalStyle, highlightedStyle, pageWidth, fontSize, lineHeight)` consistently across cubit, layout, text, page-content tests. `AyahTextSpanBuilder.buildBase` / `buildHighlightOverlay` signatures match across builder file, cubit usage, and tests.
- **Known fragility:** Task 11's `_FakePlaybackCubit` uses `noSuchMethod` to satisfy unused `PlaybackCubit` members. If `PlaybackCubit` later becomes `sealed`/`final`, the test pattern changes — flagged inline.

---

Plan complete and saved to `docs/superpowers/plans/2026-05-14-mushaf-rendering-leak.md`.

Two execution options:

1. **Subagent-Driven (recommended)** — I dispatch a fresh subagent per task, review between tasks, fast iteration.
2. **Inline Execution** — execute tasks in this session using executing-plans, batch execution with checkpoints.

Which approach?
