# Surah List Search Redesign Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Give the surah-list screen the old pinned-header + segment-selector structure (in the current theme) with a comprehensive search (surah names, juzʼ, page, ayah text), make the continue-reading card surah-relative, and let ayah search results open the mushaf with the verse highlighted.

**Architecture:** New `search` feature in clean-architecture (domain/data/presentation) using a Strategy-style use case: `SearchQuran` orchestrates a `QuranSearchIndex` (normalized in-memory corpus) + a `NumberJumpStrategy` (inline) + a `QuranBrowseService` (juzʼ jump pages). A `SearchCubit` (debounced) drives the UI. The mushaf route gains a backward-compatible `MushafArgs` so existing `int`-extra callers are untouched.

**Tech Stack:** Flutter (FVM 3.38.1), `flutter_bloc` Cubits, `GetIt` (`sl`), `dartz` (not needed here — search is synchronous in-memory), `equatable`, `bloc_test`, `flutter_test`, the local `quran` package (`package:quran/...`), `flutter_intl` ARB localization.

**Conventions reused (verified):**
- Tests run with `fvm flutter test <path>`; analyze with `fvm flutter analyze`.
- Cubit tests use `package:bloc_test/bloc_test.dart` + `package:flutter_test/flutter_test.dart`; pure-Dart tests use plain `test()`.
- DI: data sources/repos/services/use-cases = `registerLazySingleton`; cubits = `registerFactory`. Each feature has `<feature>_di.dart` with an `init<Feature>()` called from `lib/core/di/dependency_injection.dart`.
- l10n: edit BOTH `lib/l10n/intl_en.arb` and `lib/l10n/intl_ar.arb`; placeholders need an `@key` metadata block; `lib/generated/l10n.dart` regenerates automatically on ARB save (the executing engineer may need to trigger it — see Task 11).
- Numbers shown to users use `int.toLocalized(context)` from `package:quran_app/core/helper%20functions/locale_helpers.dart`.
- The `quran` package data files are directly importable: `package:quran/quran.dart` (helpers), `package:quran/quran_text_normal.dart` (`quran_text_normal`), `package:quran/juz_data.dart` (`juz`).

---

## File Structure

**New — core**
- `lib/core/helper functions/arabic_normalizer.dart` — `normalizeArabic(String)` (pure Dart).

**New — search feature**
- `lib/features/search/domain/entities/search_result.dart` — `JumpKind`, `JumpSuggestion`, `SurahResult`, `AyahResult`, `SearchResults`.
- `lib/features/search/domain/entities/juz_browse_entry.dart` — `JuzBrowseEntry`.
- `lib/features/search/domain/repositories/quran_search_index.dart` — abstract `QuranSearchIndex`.
- `lib/features/search/domain/services/quran_browse_service.dart` — abstract `QuranBrowseService`.
- `lib/features/search/domain/usecases/search_quran.dart` — `SearchQuran`.
- `lib/features/search/data/quran_search_index_impl.dart` — `QuranSearchIndexImpl`.
- `lib/features/search/data/quran_browse_service_impl.dart` — `QuranBrowseServiceImpl`.
- `lib/features/search/presentation/cubit/search_cubit.dart` + `search_state.dart`.
- `lib/features/search/search_di.dart` — `initSearch()`.

**New — surah-list presentation**
- `lib/features/surah/presentation/pages/surah_list/widgets/browse_tab.dart` — `enum BrowseTab`.
- `lib/features/surah/presentation/pages/surah_list/widgets/search_header_delegate.dart` — pinned header (search bar + segmented selector).
- `lib/features/surah/presentation/pages/surah_list/widgets/start_reading_card.dart` — first-time card.
- `lib/features/surah/presentation/pages/surah_list/widgets/juz_browse_list.dart` — `juzBrowseSliver`.
- `lib/features/surah/presentation/pages/surah_list/widgets/page_jumper_grid.dart` — `pageJumperSliver`.
- `lib/features/surah/presentation/pages/surah_list/widgets/search_results_view.dart` — `searchResultsSlivers`.
- `lib/features/surah/presentation/pages/surah_list/widgets/surah_result_tile.dart` — `SurahResultTile`.
- `lib/features/surah/presentation/pages/surah_list/widgets/ayah_result_tile.dart` — `AyahResultTile`.
- `lib/features/surah/presentation/pages/surah_list/widgets/surah_reading_progress.dart` — `SurahProgress` + `computeSurahProgress(LastRead)`.
- `lib/features/surah/presentation/pages/mushaf/mushaf_args.dart` — `MushafArgs`.

**Modified**
- `lib/config/router/app_router.dart` — `MushafArgs` parsing (both mushaf routes), highlight focus ayah, add `SearchCubit` to the surah-list route.
- `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` — guard the last-read highlight so a route-supplied focus ayah wins.
- `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart` — new sliver structure + browse/search states.
- `lib/features/home/presentation/pages/widgets/last_read_card.dart` — surah-relative content.
- `lib/core/di/dependency_injection.dart` — call `initSearch()`.
- `lib/l10n/intl_en.arb` + `lib/l10n/intl_ar.arb` — new keys.

**Deleted (pending verification)**
- `lib/core/widgets/last_quran_read.dart` (if unused).

**Tests**
- `test/core/arabic_normalizer_test.dart`
- `test/features/search/search_quran_test.dart`
- `test/features/search/quran_search_index_impl_test.dart`
- `test/features/search/quran_browse_service_impl_test.dart`
- `test/features/search/search_cubit_test.dart`
- `test/features/surah/surah_reading_progress_test.dart`

---

## Task 1: Arabic text normalizer

**Files:**
- Create: `lib/core/helper functions/arabic_normalizer.dart`
- Test: `test/core/arabic_normalizer_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/core/arabic_normalizer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/helper%20functions/arabic_normalizer.dart';

void main() {
  group('normalizeArabic', () {
    test('strips tashkil (harakat)', () {
      expect(normalizeArabic('مُحَمَّدٌ'), 'محمد');
    });
    test('unifies alef forms أ إ آ ٱ to ا', () {
      expect(normalizeArabic('أحمد'), 'احمد');
      expect(normalizeArabic('إيمان'), 'ايمان');
      expect(normalizeArabic('آدم'), 'ادم');
    });
    test('maps ى to ي and ة to ه', () {
      expect(normalizeArabic('إلى'), 'الي');
      expect(normalizeArabic('سورة'), 'سوره');
    });
    test('removes tatweel', () {
      expect(normalizeArabic('الـلـه'), 'الله');
    });
    test('lowercases and trims latin, collapses inner whitespace', () {
      expect(normalizeArabic('  Al-Fatiha '), 'al-fatiha');
      expect(normalizeArabic('a   b'), 'a b');
    });
    test('empty stays empty', () {
      expect(normalizeArabic('   '), '');
    });
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/core/arabic_normalizer_test.dart`
Expected: FAIL — `Error: Couldn't resolve the package 'quran_app' ... arabic_normalizer.dart` / "normalizeArabic isn't defined".

- [ ] **Step 3: Write minimal implementation**

```dart
// lib/core/helper functions/arabic_normalizer.dart

/// Normalizes Arabic/Latin text for tolerant substring search:
/// strips harakat + superscript alef, removes tatweel, unifies alef forms
/// (أ إ آ ٱ → ا), maps ى → ي and ة → ه, lowercases Latin, and collapses
/// whitespace. Pure Dart — no Flutter imports (safe for the domain layer).
String normalizeArabic(String input) {
  final buffer = StringBuffer();
  for (final rune in input.runes) {
    // Harakat / Quranic marks (064B–065F) and superscript alef (0670): drop.
    if (rune >= 0x064B && rune <= 0x065F) continue;
    if (rune == 0x0670) continue;
    // Tatweel (kashida): drop.
    if (rune == 0x0640) continue;
    switch (rune) {
      case 0x0623: // أ
      case 0x0625: // إ
      case 0x0622: // آ
      case 0x0671: // ٱ
        buffer.writeCharCode(0x0627); // ا
        break;
      case 0x0649: // ى
        buffer.writeCharCode(0x064A); // ي
        break;
      case 0x0629: // ة
        buffer.writeCharCode(0x0647); // ه
        break;
      default:
        buffer.writeCharCode(rune);
    }
  }
  return buffer
      .toString()
      .toLowerCase()
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/core/arabic_normalizer_test.dart`
Expected: PASS (6 tests).

- [ ] **Step 5: Commit**

```bash
git add "lib/core/helper functions/arabic_normalizer.dart" test/core/arabic_normalizer_test.dart
git commit -m "feat(search): add Arabic text normalizer for tolerant search"
```

---

## Task 2: Search result entities

**Files:**
- Create: `lib/features/search/domain/entities/search_result.dart`
- Create: `lib/features/search/domain/entities/juz_browse_entry.dart`

- [ ] **Step 1: Write the entities**

```dart
// lib/features/search/domain/entities/search_result.dart
import 'package:equatable/equatable.dart';

enum JumpKind { page, juz }

/// A "go to page N" / "go to juzʼ N" shortcut shown when the query is numeric.
class JumpSuggestion extends Equatable {
  final JumpKind kind;
  final int number; // the page or juzʼ number the user typed
  final int page; // mushaf page to navigate to
  const JumpSuggestion({
    required this.kind,
    required this.number,
    required this.page,
  });

  @override
  List<Object?> get props => [kind, number, page];
}

class SurahResult extends Equatable {
  final int number;
  final String arabicName;
  final String englishName;
  final int ayahCount;
  final String revelationPlace; // 'Makkah' / 'Madinah'
  final int page;
  const SurahResult({
    required this.number,
    required this.arabicName,
    required this.englishName,
    required this.ayahCount,
    required this.revelationPlace,
    required this.page,
  });

  @override
  List<Object?> get props =>
      [number, arabicName, englishName, ayahCount, revelationPlace, page];
}

class AyahResult extends Equatable {
  final int surah;
  final int ayah;
  final String text;
  final String surahArabicName;
  final int page;
  const AyahResult({
    required this.surah,
    required this.ayah,
    required this.text,
    required this.surahArabicName,
    required this.page,
  });

  @override
  List<Object?> get props => [surah, ayah, text, surahArabicName, page];
}

/// Grouped search output. [ayahTotalMatches] may exceed `ayahs.length` when the
/// display cap kicks in — the UI shows a "+N more" note instead of truncating
/// silently.
class SearchResults extends Equatable {
  final List<JumpSuggestion> suggestions;
  final List<SurahResult> surahs;
  final List<AyahResult> ayahs;
  final int ayahTotalMatches;

  const SearchResults({
    required this.suggestions,
    required this.surahs,
    required this.ayahs,
    required this.ayahTotalMatches,
  });

  static const SearchResults empty = SearchResults(
    suggestions: [],
    surahs: [],
    ayahs: [],
    ayahTotalMatches: 0,
  );

  bool get isEmpty =>
      suggestions.isEmpty && surahs.isEmpty && ayahs.isEmpty;

  @override
  List<Object?> get props =>
      [suggestions, surahs, ayahs, ayahTotalMatches];
}
```

```dart
// lib/features/search/domain/entities/juz_browse_entry.dart
import 'package:equatable/equatable.dart';

class JuzBrowseEntry extends Equatable {
  final int number; // 1..30
  final int firstPage;
  final String firstSurahArabicName;
  final String lastSurahArabicName;
  const JuzBrowseEntry({
    required this.number,
    required this.firstPage,
    required this.firstSurahArabicName,
    required this.lastSurahArabicName,
  });

  @override
  List<Object?> get props =>
      [number, firstPage, firstSurahArabicName, lastSurahArabicName];
}
```

- [ ] **Step 2: Verify it compiles**

Run: `fvm flutter analyze lib/features/search/domain/entities`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/search/domain/entities
git commit -m "feat(search): add search result + juz browse entities"
```

---

## Task 3: Domain ports (search index + browse service)

**Files:**
- Create: `lib/features/search/domain/repositories/quran_search_index.dart`
- Create: `lib/features/search/domain/services/quran_browse_service.dart`

- [ ] **Step 1: Write the abstract ports**

```dart
// lib/features/search/domain/repositories/quran_search_index.dart
import '../entities/search_result.dart';

abstract class QuranSearchIndex {
  /// [normalizedQuery] is already normalized via normalizeArabic and non-empty.
  List<SurahResult> searchSurahNames(String normalizedQuery);

  /// Returns up to [limit] ayah matches plus the total match count (for the
  /// "+N more" footer).
  ({List<AyahResult> results, int total}) searchAyahText(
    String normalizedQuery, {
    int limit,
  });
}
```

```dart
// lib/features/search/domain/services/quran_browse_service.dart
import '../entities/juz_browse_entry.dart';

abstract class QuranBrowseService {
  /// First mushaf page of the given juzʼ (1..30).
  int firstPageOfJuz(int juz);

  /// The 30 ajzaʼ, each with its first page and surah span (for browse mode).
  List<JuzBrowseEntry> juzEntries();
}
```

- [ ] **Step 2: Verify it compiles**

Run: `fvm flutter analyze lib/features/search/domain`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/search/domain/repositories lib/features/search/domain/services
git commit -m "feat(search): add QuranSearchIndex + QuranBrowseService ports"
```

---

## Task 4: SearchQuran use case

**Files:**
- Create: `lib/features/search/domain/usecases/search_quran.dart`
- Test: `test/features/search/search_quran_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/search/search_quran_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/search/domain/entities/juz_browse_entry.dart';
import 'package:quran_app/features/search/domain/entities/search_result.dart';
import 'package:quran_app/features/search/domain/repositories/quran_search_index.dart';
import 'package:quran_app/features/search/domain/services/quran_browse_service.dart';
import 'package:quran_app/features/search/domain/usecases/search_quran.dart';

class _FakeIndex implements QuranSearchIndex {
  @override
  List<SurahResult> searchSurahNames(String nq) {
    if (nq.contains('رحمن') || nq.contains('rahman')) {
      return const [
        SurahResult(
          number: 55,
          arabicName: 'الرحمن',
          englishName: 'The Beneficent',
          ayahCount: 78,
          revelationPlace: 'Madinah',
          page: 531,
        ),
      ];
    }
    return const [];
  }

  @override
  ({List<AyahResult> results, int total}) searchAyahText(String nq,
      {int limit = 100}) {
    if (nq.contains('رحمن')) {
      return (
        results: const [
          AyahResult(
            surah: 1,
            ayah: 1,
            text: 'بسم الله الرحمان الرحيم',
            surahArabicName: 'الفاتحة',
            page: 1,
          ),
        ],
        total: 3,
      );
    }
    return (results: const <AyahResult>[], total: 0);
  }
}

class _FakeBrowse implements QuranBrowseService {
  @override
  int firstPageOfJuz(int juz) => juz * 20; // deterministic stub
  @override
  List<JuzBrowseEntry> juzEntries() => const [];
}

void main() {
  final sut = SearchQuran(_FakeIndex(), _FakeBrowse());

  test('empty query returns empty results', () {
    final r = sut('   ');
    expect(r.isEmpty, isTrue);
    expect(identical(r, SearchResults.empty), isTrue);
  });

  test('numeric query in page range adds a page suggestion', () {
    final r = sut('50');
    expect(r.suggestions, hasLength(1));
    expect(r.suggestions.first.kind, JumpKind.page);
    expect(r.suggestions.first.page, 50);
  });

  test('numeric query in juz range adds both page and juz suggestions', () {
    final r = sut('5');
    expect(r.suggestions.map((s) => s.kind),
        containsAll([JumpKind.page, JumpKind.juz]));
    final juz = r.suggestions.firstWhere((s) => s.kind == JumpKind.juz);
    expect(juz.page, 100); // _FakeBrowse.firstPageOfJuz(5) == 100
  });

  test('out-of-range number yields no suggestions', () {
    expect(sut('999').suggestions, isEmpty);
  });

  test('arabic text query returns grouped surah + ayah matches', () {
    final r = sut('الرحمن');
    expect(r.surahs.single.number, 55);
    expect(r.ayahs.single.surah, 1);
    expect(r.ayahTotalMatches, 3);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/search/search_quran_test.dart`
Expected: FAIL — "SearchQuran isn't defined".

- [ ] **Step 3: Write the use case**

```dart
// lib/features/search/domain/usecases/search_quran.dart
import 'package:quran_app/core/helper%20functions/arabic_normalizer.dart';

import '../entities/search_result.dart';
import '../repositories/quran_search_index.dart';
import '../services/quran_browse_service.dart';

/// Comprehensive Quran search: number-jump suggestions (page/juzʼ), surah-name
/// matches, and ayah-text matches, grouped into [SearchResults].
class SearchQuran {
  final QuranSearchIndex _index;
  final QuranBrowseService _browse;
  const SearchQuran(this._index, this._browse);

  static const int ayahLimit = 100;

  SearchResults call(String rawQuery) {
    final trimmed = rawQuery.trim();
    if (trimmed.isEmpty) return SearchResults.empty;

    final suggestions = _numberJump(trimmed);
    final nq = normalizeArabic(trimmed);
    if (nq.isEmpty) {
      return SearchResults(
        suggestions: suggestions,
        surahs: const [],
        ayahs: const [],
        ayahTotalMatches: 0,
      );
    }
    final surahs = _index.searchSurahNames(nq);
    final ayah = _index.searchAyahText(nq, limit: ayahLimit);
    return SearchResults(
      suggestions: suggestions,
      surahs: surahs,
      ayahs: ayah.results,
      ayahTotalMatches: ayah.total,
    );
  }

  List<JumpSuggestion> _numberJump(String query) {
    final n = int.tryParse(query);
    if (n == null) return const [];
    final out = <JumpSuggestion>[];
    if (n >= 1 && n <= 604) {
      out.add(JumpSuggestion(kind: JumpKind.page, number: n, page: n));
    }
    if (n >= 1 && n <= 30) {
      out.add(JumpSuggestion(
        kind: JumpKind.juz,
        number: n,
        page: _browse.firstPageOfJuz(n),
      ));
    }
    return out;
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/search/search_quran_test.dart`
Expected: PASS (5 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/search/domain/usecases/search_quran.dart test/features/search/search_quran_test.dart
git commit -m "feat(search): add SearchQuran use case with number-jump strategy"
```

---

## Task 5: QuranSearchIndexImpl (data)

**Files:**
- Create: `lib/features/search/data/quran_search_index_impl.dart`
- Test: `test/features/search/quran_search_index_impl_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/search/quran_search_index_impl_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/helper%20functions/arabic_normalizer.dart';
import 'package:quran_app/features/search/data/quran_search_index_impl.dart';

void main() {
  final index = QuranSearchIndexImpl.build();

  test('matches a surah by Arabic name fragment', () {
    final r = index.searchSurahNames(normalizeArabic('فاتح'));
    expect(r.any((s) => s.number == 1), isTrue);
  });

  test('matches a surah by English name fragment', () {
    final r = index.searchSurahNames(normalizeArabic('opening'));
    expect(r.any((s) => s.number == 1), isTrue);
  });

  test('matches a surah by its number', () {
    final r = index.searchSurahNames(normalizeArabic('114'));
    expect(r.any((s) => s.number == 114), isTrue);
  });

  test('matches ayah text present in the corpus (Al-Fatiha basmala)', () {
    final r = index.searchAyahText(normalizeArabic('الرحمان'));
    expect(r.results, isNotEmpty);
    expect(r.total, greaterThan(0));
    final first = r.results.firstWhere((a) => a.surah == 1 && a.ayah == 1);
    expect(first.page, 1);
  });

  test('caps results at limit but reports the real total', () {
    final r = index.searchAyahText(normalizeArabic('الله'), limit: 5);
    expect(r.results.length, lessThanOrEqualTo(5));
    expect(r.total, greaterThanOrEqualTo(r.results.length));
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/search/quran_search_index_impl_test.dart`
Expected: FAIL — "QuranSearchIndexImpl isn't defined".

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/search/data/quran_search_index_impl.dart
import 'package:quran/quran.dart' as quran;
import 'package:quran/quran_text_normal.dart' as corpus;
import 'package:quran_app/core/helper%20functions/arabic_normalizer.dart';

import '../domain/entities/search_result.dart';
import '../domain/repositories/quran_search_index.dart';

class _IndexedAyah {
  final int surah;
  final int ayah;
  final String text;
  final String norm;
  const _IndexedAyah(this.surah, this.ayah, this.text, this.norm);
}

/// In-memory normalized index over the 6,236-ayah corpus + the 114 surahs.
/// Built once (registered as a lazy singleton). Ayah pages are computed lazily
/// per match (≤ limit) to avoid a 6k× page lookup at build time.
class QuranSearchIndexImpl implements QuranSearchIndex {
  QuranSearchIndexImpl._(this._ayahs, this._surahs, this._surahNorms);

  final List<_IndexedAyah> _ayahs;
  final List<SurahResult> _surahs;
  final List<String> _surahNorms; // parallel to _surahs: "arabic english number"

  factory QuranSearchIndexImpl.build() {
    final ayahs = <_IndexedAyah>[];
    for (final raw in corpus.quran_text_normal) {
      final e = raw as Map;
      final s = e['surah_number'] as int;
      final a = e['verse_number'] as int;
      final t = e['content'] as String;
      ayahs.add(_IndexedAyah(s, a, t, normalizeArabic(t)));
    }

    final surahs = <SurahResult>[];
    final surahNorms = <String>[];
    for (int id = 1; id <= 114; id++) {
      final ar = quran.getSurahNameArabic(id);
      final en = quran.getSurahNameEnglish(id);
      surahs.add(SurahResult(
        number: id,
        arabicName: ar,
        englishName: en,
        ayahCount: quran.getVerseCount(id),
        revelationPlace: quran.getPlaceOfRevelation(id),
        page: quran.getPageNumber(id, 1),
      ));
      surahNorms.add('${normalizeArabic(ar)} ${en.toLowerCase()} $id');
    }
    return QuranSearchIndexImpl._(ayahs, surahs, surahNorms);
  }

  @override
  List<SurahResult> searchSurahNames(String nq) {
    final out = <SurahResult>[];
    for (int i = 0; i < _surahs.length; i++) {
      if (_surahNorms[i].contains(nq)) out.add(_surahs[i]);
    }
    return out;
  }

  @override
  ({List<AyahResult> results, int total}) searchAyahText(String nq,
      {int limit = 100}) {
    final results = <AyahResult>[];
    int total = 0;
    for (final a in _ayahs) {
      if (!a.norm.contains(nq)) continue;
      total++;
      if (results.length < limit) {
        results.add(AyahResult(
          surah: a.surah,
          ayah: a.ayah,
          text: a.text,
          surahArabicName: quran.getSurahNameArabic(a.surah),
          page: quran.getPageNumber(a.surah, a.ayah),
        ));
      }
    }
    return (results: results, total: total);
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/search/quran_search_index_impl_test.dart`
Expected: PASS (5 tests). If the "الرحمان" test fails, the corpus uses a different spelling — see the orthography note in the spec §6 and Task 17; pick a fragment that exists in the corpus and adjust the normalizer only if a *common* query misses.

- [ ] **Step 5: Commit**

```bash
git add lib/features/search/data/quran_search_index_impl.dart test/features/search/quran_search_index_impl_test.dart
git commit -m "feat(search): add in-memory QuranSearchIndex implementation"
```

---

## Task 6: QuranBrowseServiceImpl (data)

**Files:**
- Create: `lib/features/search/data/quran_browse_service_impl.dart`
- Test: `test/features/search/quran_browse_service_impl_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/search/quran_browse_service_impl_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/search/data/quran_browse_service_impl.dart';

void main() {
  final sut = QuranBrowseServiceImpl();

  test('juzʼ 1 starts on page 1', () {
    expect(sut.firstPageOfJuz(1), 1);
  });

  test('juzʼ first pages increase monotonically', () {
    expect(sut.firstPageOfJuz(2), greaterThan(sut.firstPageOfJuz(1)));
    expect(sut.firstPageOfJuz(30), greaterThan(sut.firstPageOfJuz(29)));
  });

  test('produces 30 browse entries with non-empty surah spans', () {
    final entries = sut.juzEntries();
    expect(entries, hasLength(30));
    expect(entries.first.number, 1);
    expect(entries.first.firstPage, 1);
    expect(entries.first.firstSurahArabicName, isNotEmpty);
    expect(entries.last.number, 30);
  });
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/search/quran_browse_service_impl_test.dart`
Expected: FAIL — "QuranBrowseServiceImpl isn't defined".

- [ ] **Step 3: Write the implementation**

```dart
// lib/features/search/data/quran_browse_service_impl.dart
import 'package:quran/juz_data.dart' as jd;
import 'package:quran/quran.dart' as quran;

import '../domain/entities/juz_browse_entry.dart';
import '../domain/services/quran_browse_service.dart';

class QuranBrowseServiceImpl implements QuranBrowseService {
  @override
  int firstPageOfJuz(int juz) {
    final entry = jd.juz[juz - 1];
    final surahs = (entry['surahs'] as List).cast<int>();
    final firstSurah = surahs.first;
    final verses = entry['verses'] as Map;
    final startVerse = (verses[firstSurah] as List).first as int;
    return quran.getPageNumber(firstSurah, startVerse);
  }

  @override
  List<JuzBrowseEntry> juzEntries() {
    return List.generate(30, (i) {
      final n = i + 1;
      final surahs = (jd.juz[i]['surahs'] as List).cast<int>();
      return JuzBrowseEntry(
        number: n,
        firstPage: firstPageOfJuz(n),
        firstSurahArabicName: quran.getSurahNameArabic(surahs.first),
        lastSurahArabicName: quran.getSurahNameArabic(surahs.last),
      );
    });
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/search/quran_browse_service_impl_test.dart`
Expected: PASS (3 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/search/data/quran_browse_service_impl.dart test/features/search/quran_browse_service_impl_test.dart
git commit -m "feat(search): add QuranBrowseService implementation (juz jump + browse)"
```

---

## Task 7: SearchCubit (debounced)

**Files:**
- Create: `lib/features/search/presentation/cubit/search_state.dart`
- Create: `lib/features/search/presentation/cubit/search_cubit.dart`
- Test: `test/features/search/search_cubit_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/search/search_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/search/domain/entities/juz_browse_entry.dart';
import 'package:quran_app/features/search/domain/entities/search_result.dart';
import 'package:quran_app/features/search/domain/repositories/quran_search_index.dart';
import 'package:quran_app/features/search/domain/services/quran_browse_service.dart';
import 'package:quran_app/features/search/domain/usecases/search_quran.dart';
import 'package:quran_app/features/search/presentation/cubit/search_cubit.dart';
import 'package:quran_app/features/search/presentation/cubit/search_state.dart';

class _FakeIndex implements QuranSearchIndex {
  @override
  List<SurahResult> searchSurahNames(String nq) => const [
        SurahResult(
          number: 55,
          arabicName: 'الرحمن',
          englishName: 'The Beneficent',
          ayahCount: 78,
          revelationPlace: 'Madinah',
          page: 531,
        ),
      ];
  @override
  ({List<AyahResult> results, int total}) searchAyahText(String nq,
          {int limit = 100}) =>
      (results: const <AyahResult>[], total: 0);
}

class _FakeBrowse implements QuranBrowseService {
  @override
  int firstPageOfJuz(int juz) => 1;
  @override
  List<JuzBrowseEntry> juzEntries() => const [];
}

void main() {
  SearchCubit build() => SearchCubit(SearchQuran(_FakeIndex(), _FakeBrowse()));

  blocTest<SearchCubit, SearchState>(
    'non-empty query emits searching then results after debounce',
    build: build,
    act: (c) => c.queryChanged('rahman'),
    wait: const Duration(milliseconds: 350),
    expect: () => [
      isA<SearchState>()
          .having((s) => s.query, 'query', 'rahman')
          .having((s) => s.isSearching, 'isSearching', true),
      isA<SearchState>()
          .having((s) => s.isSearching, 'isSearching', false)
          .having((s) => s.results.surahs.single.number, 'surah', 55),
    ],
  );

  blocTest<SearchCubit, SearchState>(
    'empty query emits idle immediately',
    build: build,
    act: (c) => c.queryChanged('   '),
    expect: () => [
      isA<SearchState>()
          .having((s) => s.query, 'query', '')
          .having((s) => s.results.isEmpty, 'empty', true),
    ],
  );
}
```

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/search/search_cubit_test.dart`
Expected: FAIL — "SearchCubit isn't defined".

- [ ] **Step 3: Write the state and cubit**

```dart
// lib/features/search/presentation/cubit/search_state.dart
import 'package:equatable/equatable.dart';

import '../../domain/entities/search_result.dart';

class SearchState extends Equatable {
  final String query; // trimmed; empty == idle (browse mode)
  final SearchResults results;
  final bool isSearching;

  const SearchState({
    required this.query,
    required this.results,
    required this.isSearching,
  });

  factory SearchState.idle() => const SearchState(
        query: '',
        results: SearchResults.empty,
        isSearching: false,
      );

  bool get isActive => query.isNotEmpty;

  SearchState copyWith({
    String? query,
    SearchResults? results,
    bool? isSearching,
  }) =>
      SearchState(
        query: query ?? this.query,
        results: results ?? this.results,
        isSearching: isSearching ?? this.isSearching,
      );

  @override
  List<Object?> get props => [query, results, isSearching];
}
```

```dart
// lib/features/search/presentation/cubit/search_cubit.dart
import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/search_quran.dart';
import 'search_state.dart';

class SearchCubit extends Cubit<SearchState> {
  SearchCubit(this._search) : super(SearchState.idle());

  final SearchQuran _search;
  Timer? _debounce;
  static const _debounceMs = 200;

  void queryChanged(String raw) {
    _debounce?.cancel();
    final q = raw.trim();
    if (q.isEmpty) {
      emit(SearchState.idle());
      return;
    }
    // Reflect the active query immediately so the UI swaps to results mode,
    // then run the (cheap, in-memory) search after a short debounce.
    emit(state.copyWith(query: q, isSearching: true));
    _debounce = Timer(const Duration(milliseconds: _debounceMs), () {
      final results = _search(q);
      emit(SearchState(query: q, results: results, isSearching: false));
    });
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    return super.close();
  }
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/search/search_cubit_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/search/presentation/cubit test/features/search/search_cubit_test.dart
git commit -m "feat(search): add debounced SearchCubit"
```

---

## Task 8: Search DI wiring

**Files:**
- Create: `lib/features/search/search_di.dart`
- Modify: `lib/core/di/dependency_injection.dart`

- [ ] **Step 1: Write the DI module**

```dart
// lib/features/search/search_di.dart
import 'package:quran_app/core/di/dependency_injection.dart';

import 'data/quran_browse_service_impl.dart';
import 'data/quran_search_index_impl.dart';
import 'domain/repositories/quran_search_index.dart';
import 'domain/services/quran_browse_service.dart';
import 'domain/usecases/search_quran.dart';
import 'presentation/cubit/search_cubit.dart';

void initSearch() {
  sl.registerLazySingleton<QuranSearchIndex>(
    () => QuranSearchIndexImpl.build(),
  );
  sl.registerLazySingleton<QuranBrowseService>(
    () => QuranBrowseServiceImpl(),
  );
  sl.registerLazySingleton(() => SearchQuran(sl(), sl()));
  sl.registerFactory(() => SearchCubit(sl()));
}
```

- [ ] **Step 2: Register it in the composition root**

In `lib/core/di/dependency_injection.dart`, add the import near the other feature imports:

```dart
import '../../features/search/search_di.dart';
```

And add the call inside `initGetIt()`, after `initSurahList();`:

```dart
  initSurahList();
  initSearch();
```

- [ ] **Step 3: Verify it compiles**

Run: `fvm flutter analyze lib/features/search lib/core/di/dependency_injection.dart`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add lib/features/search/search_di.dart lib/core/di/dependency_injection.dart
git commit -m "feat(search): register search dependencies in GetIt"
```

---

## Task 9: Mushaf route accepts a focus ayah (backward compatible)

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/mushaf_args.dart`
- Modify: `lib/config/router/app_router.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart:41-47`

- [ ] **Step 1: Add the args type**

```dart
// lib/features/surah/presentation/pages/mushaf/mushaf_args.dart
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

/// Navigation payload for `/mushaf`. Existing callers still pass a bare `int`
/// page (handled by the router's backward-compatible parser); search results
/// pass [focusAyah] to highlight a specific verse on arrival.
class MushafArgs {
  final int page;
  final AyahIdentifier? focusAyah;
  const MushafArgs({required this.page, this.focusAyah});
}
```

- [ ] **Step 2: Parse args + highlight focus ayah in the router**

In `lib/config/router/app_router.dart`, add the import:

```dart
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_args.dart';
```

Add a top-level private helper at the END of the file (after the closing `}` of `AppRouter`):

```dart
MushafArgs _mushafArgsFrom(Object? extra) {
  if (extra is MushafArgs) return extra;
  if (extra is int) return MushafArgs(page: extra);
  return const MushafArgs(page: 1);
}
```

Replace the `mushafPath` route builder body (currently `app_router.dart:116-122`) with:

```dart
          builder: (context, state) {
            final args = _mushafArgsFrom(state.extra);
            return BlocProvider(
              create: (_) {
                final cubit = sl<MushafCubit>(param1: args.page);
                final focus = args.focusAyah;
                if (focus != null && focus.ayah > 0) {
                  cubit.toggleHighlight(focus);
                }
                return cubit;
              },
              child: MushafPage(initialPage: args.page),
            );
          },
```

Replace the `mushafImagePath` route builder body (currently `app_router.dart:128-134`) with the identical block (same code as above).

- [ ] **Step 3: Guard the last-read auto-highlight so the focus ayah wins**

In `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`, inside `initState` (lines 41-46), change the post-frame callback to bail out when a highlight is already set (the route may have set the focus ayah):

```dart
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mushafCubit.state.highlightedAyah != null) return; // focus ayah already set
      final last = _lastReadCubit.state;
      if (last?.ayah == null) return;
      if (last!.page != widget.initialPage) return;
      _mushafCubit.toggleHighlight(last.ayah!);
    });
```

- [ ] **Step 4: Verify it compiles and existing callers still work**

Run: `fvm flutter analyze lib/config/router/app_router.dart lib/features/surah/presentation/pages/mushaf`
Expected: "No issues found!" (existing `extra: int` callers in `surah_list_tile.dart`, `last_read_card.dart`, bookmarks remain valid — the parser accepts `int`.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/mushaf_args.dart lib/config/router/app_router.dart lib/features/surah/presentation/pages/mushaf/mushaf_page.dart
git commit -m "feat(mushaf): accept optional focus ayah via MushafArgs (backward compatible)"
```

---

## Task 10: Surah-relative reading progress

**Files:**
- Create: `lib/features/surah/presentation/pages/surah_list/widgets/surah_reading_progress.dart`
- Test: `test/features/surah/surah_reading_progress_test.dart`
- Modify: `lib/features/home/presentation/pages/widgets/last_read_card.dart` (after Task 11 adds l10n keys)

- [ ] **Step 1: Write the failing test**

```dart
// test/features/surah/surah_reading_progress_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_reading_progress.dart';

void main() {
  test('ayah-based progress uses verse count of the surah', () {
    // Al-Baqarah (2) has 286 ayahs; ayah 143 ≈ 50%.
    final p = computeSurahProgress(
      const LastRead(page: 22, ayah: AyahIdentifier(surah: 2, ayah: 143)),
    );
    expect(p.surahNumber, 2);
    expect(p.ayahBased, isTrue);
    expect(p.ayahCurrent, 143);
    expect(p.ayahTotal, 286);
    expect(p.fraction, closeTo(143 / 286, 0.0001));
    expect(p.surahArabicName, isNotEmpty);
  });

  test('page-only progress derives the surah from the page', () {
    // Page 1 is Al-Fatiha (surah 1).
    final p = computeSurahProgress(const LastRead(page: 1));
    expect(p.surahNumber, 1);
    expect(p.ayahBased, isFalse);
    expect(p.fraction, inInclusiveRange(0.0, 1.0));
  });
}
```

(Confirm `LastRead`'s constructor is `const LastRead({required this.page, this.ayah})` — it is, per `lib/features/surah/domain/entities/last_read.dart`. If `LastRead` is not `const`-constructible, drop the `const` keywords in the test.)

- [ ] **Step 2: Run test to verify it fails**

Run: `fvm flutter test test/features/surah/surah_reading_progress_test.dart`
Expected: FAIL — "computeSurahProgress isn't defined".

- [ ] **Step 3: Write the helper**

```dart
// lib/features/surah/presentation/pages/surah_list/widgets/surah_reading_progress.dart
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/surah/domain/entities/last_read.dart';

/// Reading progress expressed relative to the *current surah* (not the whole
/// 604-page mushaf). Ayah-based when the last-read ayah is known, else derived
/// from the page's position within the surah's page range.
class SurahProgress {
  final int surahNumber;
  final String surahArabicName;
  final int page;
  final bool ayahBased;
  final int? ayahCurrent; // null when page-based
  final int ayahTotal; // total ayahs in the surah
  final double fraction; // 0..1

  const SurahProgress({
    required this.surahNumber,
    required this.surahArabicName,
    required this.page,
    required this.ayahBased,
    required this.ayahCurrent,
    required this.ayahTotal,
    required this.fraction,
  });
}

SurahProgress computeSurahProgress(LastRead last) {
  final surah = last.ayah?.surah ?? _firstSurahOfPage(last.page);
  final total = quran.getVerseCount(surah);

  if (last.ayah != null) {
    final current = last.ayah!.ayah.clamp(1, total);
    return SurahProgress(
      surahNumber: surah,
      surahArabicName: quran.getSurahNameArabic(surah),
      page: last.page,
      ayahBased: true,
      ayahCurrent: current,
      ayahTotal: total,
      fraction: current / total,
    );
  }

  final firstPage = quran.getPageNumber(surah, 1);
  final lastPage = quran.getPageNumber(surah, total);
  final span = (lastPage - firstPage + 1).clamp(1, 604);
  final pos = (last.page - firstPage + 1).clamp(1, span);
  return SurahProgress(
    surahNumber: surah,
    surahArabicName: quran.getSurahNameArabic(surah),
    page: last.page,
    ayahBased: false,
    ayahCurrent: null,
    ayahTotal: total,
    fraction: pos / span,
  );
}

int _firstSurahOfPage(int page) {
  final data = quran.getPageData(page).cast<Map>();
  final valid = data.firstWhere(
    (e) => !(e['start'] == 0 && e['end'] == 0),
    orElse: () => const {},
  );
  return (valid['surah'] as int?) ?? 1;
}
```

- [ ] **Step 4: Run test to verify it passes**

Run: `fvm flutter test test/features/surah/surah_reading_progress_test.dart`
Expected: PASS (2 tests).

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/surah_list/widgets/surah_reading_progress.dart test/features/surah/surah_reading_progress_test.dart
git commit -m "feat(surah): add surah-relative reading-progress helper"
```

(The `LastReadCard` UI wiring lands in Task 12, after the l10n keys exist.)

---

## Task 11: Localization keys

**Files:**
- Modify: `lib/l10n/intl_en.arb`
- Modify: `lib/l10n/intl_ar.arb`

- [ ] **Step 1: Add the English keys**

Insert these key/value pairs into `lib/l10n/intl_en.arb` (place them before the final closing `}`; keep valid JSON — add a comma after the previous last entry). Placeholder keys MUST be immediately followed by their `@key` metadata block:

```json
  "search_quran_hint": "Search surah, juzʼ, page, or ayah…",
  "tab_surahs": "Surahs",
  "tab_juz": "Juzʼ",
  "tab_pages": "Pages",
  "jump_to_page_header": "Go to page",
  "all_juz": "All Juzʼ",
  "juz_label": "Juzʼ {number}",
  "@juz_label": {
    "placeholders": { "number": { "type": "Object" } }
  },
  "go_to_page": "Go to page {number}",
  "@go_to_page": {
    "placeholders": { "number": { "type": "Object" } }
  },
  "go_to_juz": "Go to Juzʼ {number}",
  "@go_to_juz": {
    "placeholders": { "number": { "type": "Object" } }
  },
  "search_section_surahs": "Surahs",
  "search_section_ayahs": "Ayahs",
  "ayahs_count": "{count} ayahs",
  "@ayahs_count": {
    "placeholders": { "count": { "type": "Object" } }
  },
  "search_more_results": "+{count} more — refine your search",
  "@search_more_results": {
    "placeholders": { "count": { "type": "Object" } }
  },
  "search_no_results": "No results",
  "start_reading": "Start reading",
  "start_reading_subtitle": "Begin with Al-Fatiha",
  "surah_ayah_label": "{surah} · Ayah {ayah}",
  "@surah_ayah_label": {
    "placeholders": { "surah": { "type": "Object" }, "ayah": { "type": "Object" } }
  },
  "bookmarks_title": "Bookmarks"
```

(`type: "Object"` matches the project's existing localized-number pattern — values are passed as already-localized strings via `int.toLocalized(context)`. `surahs_count`/`page_label` in this project use `int`, but our new placeholders receive pre-localized strings, so `Object` is correct here.)

- [ ] **Step 2: Add the matching Arabic keys**

Insert the parallel translations into `lib/l10n/intl_ar.arb` (same key names, with their `@key` blocks):

```json
  "search_quran_hint": "ابحث عن سورة أو جزء أو صفحة أو آية…",
  "tab_surahs": "السور",
  "tab_juz": "الأجزاء",
  "tab_pages": "الصفحات",
  "jump_to_page_header": "انتقل إلى صفحة",
  "all_juz": "كل الأجزاء",
  "juz_label": "الجزء {number}",
  "@juz_label": {
    "placeholders": { "number": { "type": "Object" } }
  },
  "go_to_page": "انتقل إلى صفحة {number}",
  "@go_to_page": {
    "placeholders": { "number": { "type": "Object" } }
  },
  "go_to_juz": "انتقل إلى الجزء {number}",
  "@go_to_juz": {
    "placeholders": { "number": { "type": "Object" } }
  },
  "search_section_surahs": "السور",
  "search_section_ayahs": "الآيات",
  "ayahs_count": "{count} آية",
  "@ayahs_count": {
    "placeholders": { "count": { "type": "Object" } }
  },
  "search_more_results": "+{count} أخرى — حدّد بحثك",
  "@search_more_results": {
    "placeholders": { "count": { "type": "Object" } }
  },
  "search_no_results": "لا توجد نتائج",
  "start_reading": "ابدأ القراءة",
  "start_reading_subtitle": "ابدأ بسورة الفاتحة",
  "surah_ayah_label": "{surah} · آية {ayah}",
  "@surah_ayah_label": {
    "placeholders": { "surah": { "type": "Object" }, "ayah": { "type": "Object" } }
  },
  "bookmarks_title": "العلامات المرجعية"
```

- [ ] **Step 3: Regenerate localization and verify**

The `flutter_intl` IDE extension regenerates `lib/generated/l10n.dart` on ARB save. If running headless (no IDE), trigger generation:

Run: `fvm dart run intl_utils:generate`
Then: `fvm flutter analyze lib/generated/l10n.dart`
Expected: generated file contains `String get search_quran_hint`, `String juz_label(Object number)`, `String surah_ayah_label(Object surah, Object ayah)`, etc. "No issues found!"

(If `intl_utils` is not a direct dependency, open `lib/l10n/intl_en.arb` in the IDE and save to trigger generation, or run `fvm flutter pub run intl_utils:generate`.)

- [ ] **Step 4: Commit**

```bash
git add lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated/l10n.dart
git commit -m "feat(l10n): add search, browse-tab, and surah-progress strings"
```

---

## Task 12: Surah-relative LastReadCard

**Files:**
- Modify: `lib/features/home/presentation/pages/widgets/last_read_card.dart`

- [ ] **Step 1: Rewrite the card body to be surah-relative**

Replace the entire `build` method of `LastReadCard` with the following (keep the imports; add the two new imports below). The card keeps the same `SurfaceCard` visual; the page badge now sits next to the surah's Arabic name, and the percent + bar are surah-relative.

Add these imports at the top of the file:

```dart
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_reading_progress.dart';
```

Replace the `build` method (currently `last_read_card.dart:27-133`) with:

```dart
  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final progress = computeSurahProgress(last);
    final percent = (progress.fraction * 100).round();
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 14,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsetsDirectional.symmetric(
                  horizontal: 9,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: scheme.onSurface.withValues(alpha: 0.12),
                  ),
                ),
                child: Text(
                  S.of(context).page_label(last.page.toLocalized(context)),
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.secondary,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  progress.surahArabicName,
                  style: TS.bold14.cairo.copyWith(color: scheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                S.of(context).progress_complete(percent.toLocalized(context)),
                style: TextStyle(
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: progress.fraction,
              minHeight: 3,
              backgroundColor: scheme.onSurface.withValues(alpha: 0.06),
              valueColor: AlwaysStoppedAnimation(scheme.secondary),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  progress.ayahBased
                      ? S.of(context).surah_ayah_label(
                            progress.surahArabicName,
                            progress.ayahCurrent!.toLocalized(context),
                          )
                      : S.of(context).page_label(
                            last.page.toLocalized(context),
                          ),
                  style: TS.bold14.cairo.copyWith(color: scheme.onSurface),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              ElevatedButton.icon(
                iconAlignment: IconAlignment.end,
                style: ElevatedButton.styleFrom(
                  backgroundColor: scheme.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsetsDirectional.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9),
                  ),
                ),
                onPressed: () =>
                    context.push(AppRouter.mushafPath, extra: last.page),
                icon: HugeIcon(
                  icon: forwardArrowIcon(context),
                  color: Colors.white,
                  size: 11,
                ),
                label: Text(
                  S.of(context).continue_reading,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
```

- [ ] **Step 2: Verify it compiles**

Run: `fvm flutter analyze lib/features/home/presentation/pages/widgets/last_read_card.dart`
Expected: "No issues found!"

- [ ] **Step 3: Commit**

```bash
git add lib/features/home/presentation/pages/widgets/last_read_card.dart
git commit -m "feat(home): make last-read card show surah name + surah-relative progress"
```

---

## Task 13: Browse-tab enum + pinned search header

**Files:**
- Create: `lib/features/surah/presentation/pages/surah_list/widgets/browse_tab.dart`
- Create: `lib/features/surah/presentation/pages/surah_list/widgets/search_header_delegate.dart`

- [ ] **Step 1: Add the browse-tab enum**

```dart
// lib/features/surah/presentation/pages/surah_list/widgets/browse_tab.dart
enum BrowseTab { surah, juz, page }
```

- [ ] **Step 2: Add the pinned header delegate**

```dart
// lib/features/surah/presentation/pages/surah_list/widgets/search_header_delegate.dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/generated/l10n.dart';

import 'browse_tab.dart';

/// Pinned header: a comprehensive search field over a browse-tab selector.
/// Stays put while the list scrolls (the old design's pinned-search behaviour).
class SearchHeaderDelegate extends SliverPersistentHeaderDelegate {
  SearchHeaderDelegate({
    required this.selectedTab,
    required this.onTabChanged,
    required this.onQueryChanged,
    required this.controller,
  });

  final BrowseTab selectedTab;
  final ValueChanged<BrowseTab> onTabChanged;
  final ValueChanged<String> onQueryChanged;
  final TextEditingController controller;

  static const double _height = 116;

  @override
  double get minExtent => _height;
  @override
  double get maxExtent => _height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    final scheme = context.colorScheme;
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          TextField(
            controller: controller,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            style: TextStyle(fontSize: 14, color: scheme.onSurface),
            decoration: InputDecoration(
              isDense: true,
              hintText: S.of(context).search_quran_hint,
              hintStyle:
                  TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              prefixIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              suffixIcon: controller.text.isEmpty
                  ? null
                  : GestureDetector(
                      onTap: () {
                        controller.clear();
                        onQueryChanged('');
                      },
                      child: HugeIcon(
                        icon: HugeIcons.strokeRoundedCancel01,
                        size: 18,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
              suffixIconConstraints: const BoxConstraints(minWidth: 40),
              filled: true,
              fillColor: scheme.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: AppSegmentedSelector<BrowseTab>(
              selected: selectedTab,
              onChanged: onTabChanged,
              options: [
                SegmentOption(
                  value: BrowseTab.surah,
                  label: S.of(context).tab_surahs,
                ),
                SegmentOption(
                  value: BrowseTab.juz,
                  label: S.of(context).tab_juz,
                ),
                SegmentOption(
                  value: BrowseTab.page,
                  label: S.of(context).tab_pages,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Always rebuild: the body re-emits a SearchState on every keystroke, which
  // reconstructs this delegate. Returning true keeps the clear-icon and tab
  // highlight in sync with the live query/tab. The header is cheap to rebuild.
  @override
  bool shouldRebuild(covariant SearchHeaderDelegate oldDelegate) => true;
}
```

- [ ] **Step 3: Verify it compiles**

Run: `fvm flutter analyze lib/features/surah/presentation/pages/surah_list/widgets/browse_tab.dart lib/features/surah/presentation/pages/surah_list/widgets/search_header_delegate.dart`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add lib/features/surah/presentation/pages/surah_list/widgets/browse_tab.dart lib/features/surah/presentation/pages/surah_list/widgets/search_header_delegate.dart
git commit -m "feat(surah): add browse-tab enum + pinned search header"
```

---

## Task 14: Browse views — start card, juzʼ list, page jumper

**Files:**
- Create: `lib/features/surah/presentation/pages/surah_list/widgets/start_reading_card.dart`
- Create: `lib/features/surah/presentation/pages/surah_list/widgets/juz_browse_list.dart`
- Create: `lib/features/surah/presentation/pages/surah_list/widgets/page_jumper_grid.dart`

- [ ] **Step 1: Start-reading card (first-time empty slot)**

```dart
// lib/features/surah/presentation/pages/surah_list/widgets/start_reading_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/generated/l10n.dart';

/// Shown in the continue-reading slot before any reading history exists.
class StartReadingCard extends StatelessWidget {
  const StartReadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 14,
      onTap: () => context.push(AppRouter.mushafPath, extra: 1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).start_reading,
                  style: TS.bold14.cairo.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 3),
                Text(
                  S.of(context).start_reading_subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          HugeIcon(
            icon: forwardArrowIcon(context),
            color: scheme.secondary,
            size: 16,
          ),
        ],
      ),
    );
  }
}
```

- [ ] **Step 2: Juzʼ browse sliver**

```dart
// lib/features/surah/presentation/pages/surah_list/widgets/juz_browse_list.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/search/domain/entities/juz_browse_entry.dart';
import 'package:quran_app/features/search/domain/services/quran_browse_service.dart';
import 'package:quran_app/generated/l10n.dart';

/// Sliver list of the 30 ajzaʼ; each row jumps to that juzʼ's first page.
Widget juzBrowseSliver(BuildContext context) {
  final entries = sl<QuranBrowseService>().juzEntries();
  return SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
    sliver: SliverList.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _JuzTile(entry: entries[i]),
    ),
  );
}

class _JuzTile extends StatelessWidget {
  const _JuzTile({required this.entry});
  final JuzBrowseEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return PrettierTap(
      onTap: () =>
          context.push(AppRouter.mushafPath, extra: entry.firstPage),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: context.cardBorder(),
          boxShadow: context.cardShadow(),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.10),
                ),
              ),
              child: Text(
                entry.number.toLocalized(context),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).juz_label(entry.number.toLocalized(context)),
                    style: TS.bold16.copyWith(color: scheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.firstSurahArabicName} – ${entry.lastSurahArabicName}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Page-jumper sliver**

```dart
// lib/features/surah/presentation/pages/surah_list/widgets/page_jumper_grid.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';

/// Sliver grid of mushaf pages 1..604; tapping a cell opens that page.
Widget pageJumperSliver(BuildContext context) {
  const totalPages = 604;
  return SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, i) => _PageCell(page: i + 1),
        childCount: totalPages,
      ),
    ),
  );
}

class _PageCell extends StatelessWidget {
  const _PageCell({required this.page});
  final int page;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return PrettierTap(
      onTap: () => context.push(AppRouter.mushafPath, extra: page),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border: context.cardBorder(),
        ),
        child: Text(
          page.toLocalized(context),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify it compiles**

Run: `fvm flutter analyze lib/features/surah/presentation/pages/surah_list/widgets/start_reading_card.dart lib/features/surah/presentation/pages/surah_list/widgets/juz_browse_list.dart lib/features/surah/presentation/pages/surah_list/widgets/page_jumper_grid.dart`
Expected: "No issues found!"

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/surah_list/widgets/start_reading_card.dart lib/features/surah/presentation/pages/surah_list/widgets/juz_browse_list.dart lib/features/surah/presentation/pages/surah_list/widgets/page_jumper_grid.dart
git commit -m "feat(surah): add start-reading card, juz browse list, page jumper"
```

---

## Task 15: Search results view (grouped) + result tiles

**Files:**
- Create: `lib/features/surah/presentation/pages/surah_list/widgets/surah_result_tile.dart`
- Create: `lib/features/surah/presentation/pages/surah_list/widgets/ayah_result_tile.dart`
- Create: `lib/features/surah/presentation/pages/surah_list/widgets/search_results_view.dart`

- [ ] **Step 1: Surah result tile**

```dart
// lib/features/surah/presentation/pages/surah_list/widgets/surah_result_tile.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/search/domain/entities/search_result.dart';

class SurahResultTile extends StatelessWidget {
  const SurahResultTile({super.key, required this.result});
  final SurahResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return PrettierTap(
      onTap: () =>
          context.push(AppRouter.mushafPath, extra: result.page),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: context.cardBorder(),
          boxShadow: context.cardShadow(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.arabicName,
                    style: TS.bold16.copyWith(color: scheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.englishName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.10),
                ),
              ),
              child: Text(
                result.number.toLocalized(context),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Ayah result tile**

```dart
// lib/features/surah/presentation/pages/surah_list/widgets/ayah_result_tile.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/search/domain/entities/search_result.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_args.dart';
import 'package:quran_app/generated/l10n.dart';

class AyahResultTile extends StatelessWidget {
  const AyahResultTile({super.key, required this.result});
  final AyahResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final meta = [
      result.surahArabicName,
      S.of(context).ayah_label(
            result.surah.toLocalized(context),
            result.ayah.toLocalized(context),
          ),
      S.of(context).page_label(result.page.toLocalized(context)),
    ].join(' · ');

    return PrettierTap(
      onTap: () => context.push(
        AppRouter.mushafPath,
        extra: MushafArgs(
          page: result.page,
          focusAyah:
              AyahIdentifier(surah: result.surah, ayah: result.ayah),
        ),
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: context.cardBorder(),
          boxShadow: context.cardShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.text,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TS.bold16.amiriQuran.copyWith(
                color: scheme.onSurface,
                height: 1.7,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              meta,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 3: Grouped results slivers**

```dart
// lib/features/surah/presentation/pages/surah_list/widgets/search_results_view.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/search/domain/entities/search_result.dart';
import 'package:quran_app/features/search/presentation/cubit/search_state.dart';
import 'package:quran_app/generated/l10n.dart';

import 'ayah_result_tile.dart';
import 'surah_result_tile.dart';

/// Builds the grouped search-result slivers (jump suggestions → surahs →
/// ayahs). Returns a single sliver (a [SliverMainAxisGroup]) so it slots
/// straight into the page's [CustomScrollView].
Widget searchResultsSliver(BuildContext context, SearchState search) {
  final scheme = context.colorScheme;
  final r = search.results;

  if (!search.isSearching && r.isEmpty) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 32),
      sliver: SliverToBoxAdapter(
        child: Center(
          child: Text(
            S.of(context).search_no_results,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  final groups = <Widget>[];

  // Jump suggestions.
  for (final s in r.suggestions) {
    groups.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        sliver: SliverToBoxAdapter(child: _JumpTile(suggestion: s)),
      ),
    );
  }

  // Surahs.
  if (r.surahs.isNotEmpty) {
    groups.add(_header(context, S.of(context).search_section_surahs,
        r.surahs.length.toLocalized(context)));
    groups.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        sliver: SliverList.separated(
          itemCount: r.surahs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => SurahResultTile(result: r.surahs[i]),
        ),
      ),
    );
  }

  // Ayahs.
  if (r.ayahs.isNotEmpty) {
    groups.add(_header(context, S.of(context).search_section_ayahs,
        r.ayahTotalMatches.toLocalized(context)));
    groups.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        sliver: SliverList.separated(
          itemCount: r.ayahs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => AyahResultTile(result: r.ayahs[i]),
        ),
      ),
    );
    final hidden = r.ayahTotalMatches - r.ayahs.length;
    if (hidden > 0) {
      groups.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          sliver: SliverToBoxAdapter(
            child: Text(
              S.of(context).search_more_results(hidden.toLocalized(context)),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
  }

  groups.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
  return SliverMainAxisGroup(slivers: groups);
}

Widget _header(BuildContext context, String label, String count) {
  return SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
    sliver: SliverToBoxAdapter(
      child: AppSectionHeader(
        label: label,
        trailing: Text(
          count,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.colorScheme.secondary,
          ),
        ),
      ),
    ),
  );
}

class _JumpTile extends StatelessWidget {
  const _JumpTile({required this.suggestion});
  final JumpSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final label = suggestion.kind == JumpKind.page
        ? S.of(context).go_to_page(suggestion.number.toLocalized(context))
        : S.of(context).go_to_juz(suggestion.number.toLocalized(context));
    return PrettierTap(
      onTap: () =>
          context.push(AppRouter.mushafPath, extra: suggestion.page),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_forward, size: 16, color: scheme.primary),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 4: Verify it compiles**

Run: `fvm flutter analyze lib/features/surah/presentation/pages/surah_list/widgets/surah_result_tile.dart lib/features/surah/presentation/pages/surah_list/widgets/ayah_result_tile.dart lib/features/surah/presentation/pages/surah_list/widgets/search_results_view.dart`
Expected: "No issues found!" (If `TS.bold16.amiriQuran` is not a valid combination, check `lib/config/theme/typography_styles.dart` — `amiriQuran` is an extension getter on `TextStyle`; `TS.bold16.amiriQuran` is valid.)

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/surah_list/widgets/surah_result_tile.dart lib/features/surah/presentation/pages/surah_list/widgets/ayah_result_tile.dart lib/features/surah/presentation/pages/surah_list/widgets/search_results_view.dart
git commit -m "feat(surah): add grouped search-results view + result tiles"
```

---

## Task 16: Rewire SurahListPageBody + provide SearchCubit + bookmark icon

**Files:**
- Modify: `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart`
- Modify: `lib/config/router/app_router.dart` (surah-list route — add `SearchCubit`)

- [ ] **Step 1: Add SearchCubit to the surah-list route**

In `lib/config/router/app_router.dart`, add the import:

```dart
import 'package:quran_app/features/search/presentation/cubit/search_cubit.dart';
```

In the `surahListPath` route's `MultiBlocProvider.providers` list (currently `app_router.dart:105-108`), add a third provider:

```dart
            providers: [
              BlocProvider(create: (_) => sl<SurahCubit>()..fetchSurahs()),
              BlocProvider(create: (_) => sl<LastReadCubit>()),
              BlocProvider(create: (_) => sl<SearchCubit>()),
            ],
```

- [ ] **Step 2: Rewrite the page body**

Replace the entire contents of `lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart` with:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_list_skeleton.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/icon_chip.dart';
import 'package:quran_app/core/widgets/design/scroll_to_top_fab.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/last_read_card.dart';
import 'package:quran_app/features/search/presentation/cubit/search_cubit.dart';
import 'package:quran_app/features/search/presentation/cubit/search_state.dart';
import 'package:quran_app/features/surah/domain/entities/surah_entity.dart';
import 'package:quran_app/features/surah/presentation/cubit/surah/surah_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/browse_tab.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/juz_browse_list.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/page_jumper_grid.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/search_header_delegate.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/search_results_view.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/start_reading_card.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart';
import 'package:quran_app/generated/l10n.dart';

class SurahListPageBody extends StatefulWidget {
  const SurahListPageBody({super.key});

  @override
  State<SurahListPageBody> createState() => _SurahListPageBodyState();
}

class _SurahListPageBodyState extends State<SurahListPageBody> {
  BrowseTab _tab = BrowseTab.surah;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenAppBar(
              label: S.of(context).the_noble_quran,
              title: S.of(context).surahs_appbar_title,
              trailing: IconChip(
                icon: const Icon(Icons.bookmark_outline),
                onPressed: () => context.push(AppRouter.bookmarksPath),
              ),
            ),
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (context, search) {
                  return ScrollToTopFab(
                    controller: _scrollController,
                    child: CustomScrollView(
                      controller: _scrollController,
                      slivers: [
                        if (!search.isActive)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 14, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: LastReadCard.maybeBuild(context) ??
                                  const StartReadingCard(),
                            ),
                          ),
                        SliverPersistentHeader(
                          pinned: true,
                          delegate: SearchHeaderDelegate(
                            selectedTab: _tab,
                            controller: _searchController,
                            onTabChanged: (t) => setState(() => _tab = t),
                            onQueryChanged: (q) =>
                                context.read<SearchCubit>().queryChanged(q),
                          ),
                        ),
                        if (search.isActive)
                          searchResultsSliver(context, search)
                        else
                          ..._browseSlivers(context),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _browseSlivers(BuildContext context) {
    switch (_tab) {
      case BrowseTab.surah:
        return _surahSlivers(context);
      case BrowseTab.juz:
        return [juzBrowseSliver(context)];
      case BrowseTab.page:
        return [pageJumperSliver(context)];
    }
  }

  List<Widget> _surahSlivers(BuildContext context) {
    final scheme = context.colorScheme;
    final surahs = context.watch<SurahCubit>().state;
    if (surahs.isEmpty) {
      return const [SliverFillRemaining(child: AppListSkeleton())];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
        sliver: SliverToBoxAdapter(
          child: AppSectionHeader(
            label: S.of(context).all_surahs,
            trailing: Text(
              S.of(context).surahs_count(surahs.length.toLocalized(context)),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.secondary,
              ),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        sliver: SliverList.separated(
          itemCount: surahs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => SurahListTile(surah: surahs[i]),
        ),
      ),
    ];
  }
}
```

(Note: `SurahEntity` is imported because `SurahCubit`'s state is `List<SurahEntity>`. The local name-filter is gone — surah-name search now flows through `SearchCubit`.)

- [ ] **Step 3: Verify it compiles**

Run: `fvm flutter analyze lib/features/surah/presentation/pages/surah_list lib/config/router/app_router.dart`
Expected: "No issues found!"

- [ ] **Step 4: Commit**

```bash
git add lib/features/surah/presentation/pages/surah_list/widgets/surah_list_page_body.dart lib/config/router/app_router.dart
git commit -m "feat(surah): rebuild surah-list with pinned search header + browse tabs"
```

---

## Task 17: Remove stale widget, full verification, normalizer reality check

**Files:**
- Delete (conditional): `lib/core/widgets/last_quran_read.dart`

- [ ] **Step 1: Check whether the stale widget is referenced**

Run: `grep -rn "last_quran_read\|LastQuranRead" lib test`
Expected: only the file's own definition (no importers). If there are importers, STOP — do not delete; leave it and note it.

- [ ] **Step 2: Delete it if unused**

If Step 1 showed no importers:

```bash
git rm lib/core/widgets/last_quran_read.dart
```

- [ ] **Step 3: Run the full analyzer**

Run: `fvm flutter analyze`
Expected: "No issues found!" Fix any issues before continuing.

- [ ] **Step 4: Run the whole test suite**

Run: `fvm flutter test`
Expected: all tests pass (including the 6 new test files).

- [ ] **Step 5: Normalizer reality check (manual, against the real corpus)**

Create a throwaway test to confirm real queries hit the corpus, then delete it:

```dart
// test/features/search/_normalizer_reality_check_test.dart  (temporary)
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/helper%20functions/arabic_normalizer.dart';
import 'package:quran_app/features/search/data/quran_search_index_impl.dart';

void main() {
  final index = QuranSearchIndexImpl.build();
  for (final q in [
    'الرحمان', // ayah text (corpus spelling)
    'العالمين',
    'قل هو الله',
    'الكوثر', // surah name
    'opening', // english name
    '114', // surah number
  ]) {
    test('query "$q" returns matches', () {
      final nq = normalizeArabic(q);
      final surahs = index.searchSurahNames(nq);
      final ayahs = index.searchAyahText(nq, limit: 5);
      // ignore: avoid_print
      print('"$q" → ${surahs.length} surahs, ${ayahs.total} ayahs');
      expect(surahs.isNotEmpty || ayahs.total > 0, isTrue,
          reason: 'common query "$q" found nothing — tune the normalizer');
    });
  }
}
```

Run: `fvm flutter test test/features/search/_normalizer_reality_check_test.dart`
Expected: all queries return at least one match. If a common query returns nothing, note it — the corpus orthography may differ (spec §6); extend `normalizeArabic` ONLY if needed, then re-run Task 1's test. When satisfied, delete the throwaway file:

```bash
rm test/features/search/_normalizer_reality_check_test.dart
```

- [ ] **Step 6: Manual smoke test in the running app**

Run the app (`fvm flutter run`, or use the `/run` skill) and verify on the surah-list screen:
1. First-time (or after clearing data): pinned header + 114-surah list, start-reading card in the top slot (no continue card).
2. Tabs switch the empty view: Surahs → 114 list; Juzʼ → 30 entries; Pages → 1–604 grid. Each navigates to the mushaf.
3. Type a surah name (Arabic and English) → appears under "Surahs".
4. Type ayah text → matches under "Ayahs"; tapping opens the right page with the verse highlighted.
5. Type a number (e.g. `50`, `5`) → jump suggestion(s) appear and navigate correctly.
6. With reading history, the continue-reading card shows the surah name + page and a surah-relative percent.
7. Bookmark icon in the app bar opens the bookmarks page.

- [ ] **Step 7: Commit**

```bash
git add -A
git commit -m "chore(surah): remove stale last_quran_read widget + verify search redesign"
```

---

## Self-Review Notes

- **Spec coverage:** Layout/pinned-header/browse-tabs (T13, T16); comprehensive search via Strategy use case + normalized index (T1–T8); ayah result highlight + backward-compatible route (T9, T15); bookmark stays ayah-level + app-bar entry (T16, no storage change — confirmed in spec §7); surah-relative continue card (T10, T12); first-time start card (T14, T16); skeleton loading preserved (T16 `AppListSkeleton`); orthography caveat verified (T17). All spec §11 acceptance criteria map to a task.
- **Type consistency:** `SearchResults`/`SurahResult`/`AyahResult`/`JumpSuggestion`/`JumpKind` defined in T2, consumed identically in T4/T5/T7/T15. `QuranSearchIndex.searchAyahText` returns `({List<AyahResult> results, int total})` everywhere. `BrowseTab` (T13) used in T13/T16. `MushafArgs` (T9) consumed in T15. `computeSurahProgress`/`SurahProgress` (T10) consumed in T12. `searchResultsSliver`, `juzBrowseSliver`, `pageJumperSliver` names match between definition and call sites.
- **No DI signature change** for `MushafCubit` (still `registerFactoryParam<MushafCubit, int, void>`); the focus ayah is applied via `toggleHighlight` in the route builder.
