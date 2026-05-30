# Hadith Search × Filters — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make hadith search respect the active chapter/grade filter (returning *all* in-scope matches), and redesign the filter sheet into a compact sheet + a small searchable chapter picker.

**Architecture:** Push the filter into the search at the data layer instead of post-filtering a truncated list in the view. Three search paths are made filter-aware: downloaded English (filter before the cap), online English (forward `status`/`chapter` to the API), and Arabic (enrich the search index with chapter + status so matches can be filtered before the cap). The UI gains a stateful compact filter sheet whose "Change" button opens a second, searchable bottom-sheet chapter picker that returns to the compact sheet on selection.

**Tech Stack:** Flutter, flutter_bloc (Cubit), dartz (`Either`), Hive, GetIt (`sl`), mocktail + flutter_test.

**Layering note:** `HadithListFilter` lives in `presentation/utils/` and **must not** reach the domain/data layers. The repository and data sources take primitive `HadithStatus? status` (domain enum) and `int? chapterId`. The cubit (presentation) accepts the `HadithListFilter` and unpacks it.

**Spec:** `docs/superpowers/specs/2026-05-30-hadith-search-filters-design.md`

**Run tests with:** `flutter test <path>` (single test: `flutter test <path> --plain-name "<name>"`).

---

## File Structure

**Create:**
- `lib/features/ahadith/data/repositories/hadith_lookups.dart` — shared `generateChapterLookups()` + `hadithStatusApiValue` map (DRY: used by both `AhadithRepositoryImpl` and `AhadithSearchRepositoryImpl`).
- `lib/features/ahadith/presentation/pages/widgets/chapter_picker_sheet.dart` — the small searchable chapter picker bottom sheet.
- `test/features/ahadith/hadith_lookups_test.dart`
- `test/features/ahadith/arabic_search_index_test.dart`

**Modify (data/domain):**
- `lib/features/ahadith/domain/repositories/ahadith_search_repository.dart` — add `status`/`chapterId` to `searchHadiths`.
- `lib/features/ahadith/data/repositories/ahadith_search_repository_impl.dart` — filter-aware routing; inject `allChapters`.
- `lib/features/ahadith/data/repositories/ahadith_repository_impl.dart` — use the shared lookup helper.
- `lib/features/ahadith/data/datasources/local/ahadith_local_data_source.dart` — `getSearchedHadiths` filters before the cap.
- `lib/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart` — `getSearchedHadiths` forwards `status`/`chapterNumber`.
- `lib/features/ahadith/data/datasources/local/ahadith_arabic_search_local_data_source.dart` — richer index value + filter before cap.
- `lib/features/ahadith/presentation/cubit/search_hadith_cubit.dart` — accept filter, store last query, re-search.
- `lib/features/ahadith/ahadith_di.dart` — pass `allChapters` to the search repo.
- `scripts/normalize_arabic_hadith.dart` — capture chapter id + status into the index.

**Modify (presentation/UI):**
- `lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart` — re-search on filter change; make `_FilterSheet` stateful; grade pills in sheet; wire the picker.

**Modify (tests):**
- `test/features/ahadith/ahadith_search_repository_impl_test.dart` — constructor + signature updates.
- `test/features/ahadith/ahadith_local_data_source_test.dart` — filter-before-cap tests.

---

## Task 1: Shared chapter-lookup + status-API-value helper

Extract the chapter lookup builder and the status→API-value map (currently private inside `AhadithRepositoryImpl`) into a shared data-layer file so the search repo can reuse them.

**Files:**
- Create: `lib/features/ahadith/data/repositories/hadith_lookups.dart`
- Create: `test/features/ahadith/hadith_lookups_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
// test/features/ahadith/hadith_lookups_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/ahadith/data/repositories/hadith_lookups.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

void main() {
  test('generateChapterLookups maps book -> {chapterId: Chapter}', () {
    final raw = {
      'sahih-bukhari': [
        {'id': 10, 'chapterNumber': 1, 'chapterArabic': 'الوحى', 'chapterEnglish': 'Revelation'},
        {'id': 11, 'chapterNumber': 2, 'chapterArabic': 'الإيمان', 'chapterEnglish': 'Belief'},
      ],
    };

    final lookups = generateChapterLookups(raw);

    expect(lookups['sahih-bukhari']!.length, 2);
    expect(lookups['sahih-bukhari']![10]!.chapterNumber, 1);
    expect(lookups['sahih-bukhari']![11]!.chapterEnglish, 'Belief');
  });

  test('hadithStatusApiValue maps daeef to the back-tick API spelling', () {
    expect(hadithStatusApiValue[HadithStatus.sahih], 'Sahih');
    expect(hadithStatusApiValue[HadithStatus.hasan], 'Hasan');
    expect(hadithStatusApiValue[HadithStatus.daeef], 'Da`eef');
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/ahadith/hadith_lookups_test.dart`
Expected: FAIL — `hadith_lookups.dart` / `generateChapterLookups` does not exist.

- [ ] **Step 3: Create the helper**

```dart
// lib/features/ahadith/data/repositories/hadith_lookups.dart
import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

/// Builds, per book slug, a map of API chapter id -> [Chapter] from the bundled
/// `all_chapters.json` structure. Shared by the ahadith and search repositories.
Map<String, Map<int, Chapter>> generateChapterLookups(Map<String, dynamic> raw) {
  return raw.map((bookSlug, chaptersList) {
    final list = chaptersList as List<dynamic>;
    final lookup = {
      for (var item in list)
        item['id'] as int: Chapter(
          id: item['id'],
          chapterNumber: item['chapterNumber'],
          chapterArabic: item['chapterArabic'],
          chapterEnglish: item['chapterEnglish'],
        ),
    };
    return MapEntry(bookSlug, lookup);
  });
}

/// The API's `status` query-param spelling for each grade (note the back-tick in
/// `Da`eef`).
const Map<HadithStatus, String> hadithStatusApiValue = {
  HadithStatus.sahih: 'Sahih',
  HadithStatus.hasan: 'Hasan',
  HadithStatus.daeef: 'Da`eef',
};
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/ahadith/hadith_lookups_test.dart`
Expected: PASS.

- [ ] **Step 5: Refactor `AhadithRepositoryImpl` to use the shared helper**

In `lib/features/ahadith/data/repositories/ahadith_repository_impl.dart`:
- Add import: `import 'package:quran_app/features/ahadith/data/repositories/hadith_lookups.dart';`
- Replace the constructor initializer `_generateLookups(allChapters)` with `generateChapterLookups(allChapters)`.
- Delete the private `static Map<String, Map<int, Chapter>> _generateLookups(...)` method (now in the helper).
- Delete the private `static const Map<HadithStatus, String> _statusApiValue = {...}` and replace its single use (in `getFilteredAhadithPage`: `status: status == null ? null : _statusApiValue[status]`) with `hadithStatusApiValue[status]`.

- [ ] **Step 6: Verify the feature still compiles & its tests pass**

Run: `flutter test test/features/ahadith/`
Expected: PASS (existing ahadith tests unaffected).

- [ ] **Step 7: Commit**

```bash
git add lib/features/ahadith/data/repositories/hadith_lookups.dart test/features/ahadith/hadith_lookups_test.dart lib/features/ahadith/data/repositories/ahadith_repository_impl.dart
git commit -m "refactor(ahadith): extract shared chapter lookup + status api map"
```

---

## Task 2: Downloaded English search — filter before the cap

`AhadithLocalDataSource.getSearchedHadiths` currently `.take(kPageLimit)` *before* any chapter/grade narrowing. Add optional `status`/`chapterId` filtering applied **before** the cap.

**Files:**
- Modify: `lib/features/ahadith/data/datasources/local/ahadith_local_data_source.dart`
- Test: `test/features/ahadith/ahadith_local_data_source_test.dart`

- [ ] **Step 1: Write the failing test**

Add to `test/features/ahadith/ahadith_local_data_source_test.dart` (inside `main()`, a new group). Note the existing `_model` helper hardcodes `chapterId: 1` / `status: 'sahih'`; add a richer factory in this file:

```dart
HadithHiveModel _modelFull(
  String number, {
  int chapterId = 1,
  String status = 'sahih',
  String english = 'en',
}) =>
    HadithHiveModel(
      hadithNumber: number,
      englishHadith: english,
      arabicHadith: 'ar',
      englishNarrator: '',
      arabicHeader: '',
      englishHeader: '',
      status: status,
      pageNumber: 1,
      bookSlug: 'sahih-bukhari',
      chapterId: chapterId,
    );

// ... inside main():
group('getSearchedHadiths with filters', () {
  test('filters by chapterId before applying the result cap', () {
    final keys = [
      'sahih-bukhari_1_1',
      'sahih-bukhari_1_2',
      'sahih-bukhari_1_3',
    ];
    when(() => box.keys).thenReturn(keys);
    when(() => box.get('sahih-bukhari_1_1'))
        .thenReturn(_modelFull('1', chapterId: 5, english: 'prayer one'));
    when(() => box.get('sahih-bukhari_1_2'))
        .thenReturn(_modelFull('2', chapterId: 9, english: 'prayer two'));
    when(() => box.get('sahih-bukhari_1_3'))
        .thenReturn(_modelFull('3', chapterId: 5, english: 'prayer three'));

    final result = sut.getSearchedHadiths(
      'prayer',
      'sahih-bukhari',
      chapterId: 5,
    );

    expect(result.map((h) => h.hadithNumber).toSet(), {'1', '3'});
  });

  test('filters by status', () {
    final keys = ['sahih-bukhari_1_1', 'sahih-bukhari_1_2'];
    when(() => box.keys).thenReturn(keys);
    when(() => box.get('sahih-bukhari_1_1'))
        .thenReturn(_modelFull('1', status: 'sahih', english: 'prayer one'));
    when(() => box.get('sahih-bukhari_1_2'))
        .thenReturn(_modelFull('2', status: 'daeef', english: 'prayer two'));

    final result = sut.getSearchedHadiths(
      'prayer',
      'sahih-bukhari',
      status: HadithStatus.daeef,
    );

    expect(result.map((h) => h.hadithNumber), ['2']);
  });
});
```

Add the import at the top of the test file if missing:
```dart
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/ahadith/ahadith_local_data_source_test.dart`
Expected: FAIL — `getSearchedHadiths` has no `status`/`chapterId` params.

- [ ] **Step 3: Implement filter-before-cap**

In `lib/features/ahadith/data/datasources/local/ahadith_local_data_source.dart`, replace the `getSearchedHadiths` method:

```dart
  List<Hadith> getSearchedHadiths(
    String query,
    String bookSlug, {
    HadithStatus? status,
    int? chapterId,
  }) {
    final String keyPrefix = "${bookSlug}_";
    final String lowercaseQuery = query.toLowerCase();

    final allKeys = hadithBox.keys.cast<String>();
    final relevantKeys = allKeys.where((key) => key.startsWith(keyPrefix));
    if (relevantKeys.isEmpty) return [];

    final List<Hadith> results = relevantKeys
        .map((key) => hadithBox.get(key))
        .whereType<HadithHiveModel>()
        .where(
          (model) =>
              model.englishHadith.toLowerCase().contains(lowercaseQuery),
        )
        .map((model) => model.toEntity())
        // Narrow by the active filter BEFORE capping, so a chapter/grade with
        // matches beyond the first page is never silently truncated away.
        .where((h) => status == null || h.status == status)
        .where((h) => chapterId == null || h.chapterId == chapterId)
        .take(kPageLimit)
        .toList();

    return AhadithHelpers.sortHadiths(results);
  }
```

(The domain `HadithStatus` enum is already imported via `hadith.dart`.)

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/ahadith/ahadith_local_data_source_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/ahadith/data/datasources/local/ahadith_local_data_source.dart test/features/ahadith/ahadith_local_data_source_test.dart
git commit -m "feat(ahadith): filter downloaded search by chapter/grade before cap"
```

---

## Task 3: Online English search — forward status/chapter to the API

**Files:**
- Modify: `lib/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart`

- [ ] **Step 1: Update `getSearchedHadiths` to accept filter params**

In `lib/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart`, replace the `getSearchedHadiths` method signature and query parameters:

```dart
  Future<List<Hadith>> getSearchedHadiths(
    String query,
    String bookSlug, {
    String? status,
    int? chapterNumber,
  }) async {
    final Response ahadithResponse;
    try {
      ahadithResponse = await dio.get(
        'https://hadithapi.com/api/hadiths/?apiKey=$hadithApiKey',
        queryParameters: {
          'paginate': kPageLimit,
          'book': bookSlug,
          'hadithEnglish': query,
          if (status != null) 'status': status,
          if (chapterNumber != null) 'chapter': chapterNumber,
        },
      );
    } on DioException catch (e) {
      // No matches comes back as 404 — that's an empty result, not an error.
      if (e.response?.statusCode == 404) return [];
      rethrow;
    }
    final List<dynamic>? dataList = ahadithResponse.data['hadiths']?['data'];

    if (dataList == null || dataList.isEmpty) return [];
    return dataList.map((e) => HadithModel.fromJson(e)).toList();
  }
```

> **Verify during implementation (spec open item #1):** confirm the `/hadiths` endpoint accepts `status` + `chapter` alongside `hadithEnglish`. If it rejects them, fall back to calling `getFilteredAhadithPage` and matching `query` against `englishHadith` client-side inside the repository.

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart`
Expected: No errors (callers updated in Task 4).

- [ ] **Step 3: Commit**

```bash
git add lib/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart
git commit -m "feat(ahadith): forward status/chapter params to remote search"
```

---

## Task 4: Search repository — thread the filter through all paths

Add `status`/`chapterId` to the repository interface and route them into each search path. Inject `allChapters` for the chapterId→chapterNumber lookup.

**Files:**
- Modify: `lib/features/ahadith/domain/repositories/ahadith_search_repository.dart`
- Modify: `lib/features/ahadith/data/repositories/ahadith_search_repository_impl.dart`
- Test: `test/features/ahadith/ahadith_search_repository_impl_test.dart`

- [ ] **Step 1: Update the failing test (signature + a new filtering test)**

In `test/features/ahadith/ahadith_search_repository_impl_test.dart`:

(a) Update the `setUp` constructor to pass `allChapters`:

```dart
  setUp(() {
    arabic = _MockArabicSearch();
    local = _MockLocal();
    remote = _MockRemote();
    sut = AhadithSearchRepositoryImpl(
      arabicSearchDataSource: arabic,
      ahadithLocalDataSource: local,
      ahadithRemoteDataSource: remote,
      allChapters: const {
        'sahih-bukhari': [
          {
            'id': 5,
            'chapterNumber': 5,
            'chapterArabic': 'الوضوء',
            'chapterEnglish': 'Ablutions',
          },
        ],
      },
    );
  });
```

(b) The existing Arabic tests call `getSearchedHadithsNumbers(query: any(named: 'query'))`. After Task 6 that method gains optional named params, but `any(named: 'query')` still matches; leave those three tests as-is **except** add the new optional params to the existing `when(...)` is not required (optional named args default). Update the `searchHadiths(...)` calls in those three tests to pass no filter (defaults). They already omit it — fine once defaults exist.

(c) Add a new group for the online English filtered path:

```dart
group('searchHadiths (English, online) — forwards filter to API', () {
  const englishQuery = 'prayer';

  test('passes status + chapterNumber derived from chapterId', () async {
    when(() => remote.getSearchedHadiths(
          any(),
          any(),
          status: any(named: 'status'),
          chapterNumber: any(named: 'chapterNumber'),
        )).thenAnswer((_) async => [_h('1')]);

    final result = await sut.searchHadiths(
      query: englishQuery,
      bookSlug: slug,
      isDownloaded: false,
      status: HadithStatus.daeef,
      chapterId: 5,
    );

    expect(result.isRight(), isTrue);
    verify(() => remote.getSearchedHadiths(
          englishQuery,
          slug,
          status: 'Da`eef',
          chapterNumber: 5, // id 5 -> chapterNumber 5 via allChapters lookup
        )).called(1);
  });
});
```

Add the import for `HadithStatus` if not present:
```dart
// already imported via hadith.dart in this file
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/ahadith/ahadith_search_repository_impl_test.dart`
Expected: FAIL — constructor has no `allChapters`; `searchHadiths` has no `status`/`chapterId`.

- [ ] **Step 3: Update the domain interface**

Replace `lib/features/ahadith/domain/repositories/ahadith_search_repository.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

abstract class AhadithSearchRepository {
  void initializeArabicBookSearch(String bookSlug);
  Future<Either<Failure, List<Hadith>>> searchHadiths({
    required String query,
    required String bookSlug,
    required bool isDownloaded,
    HadithStatus? status,
    int? chapterId,
  });
  void dispose();
}
```

- [ ] **Step 4: Update the impl**

Rewrite `lib/features/ahadith/data/repositories/ahadith_search_repository_impl.dart`:

```dart
import 'package:dartz/dartz.dart';
import 'package:dio/dio.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/helper%20functions/ahadith_helpers.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_arabic_search_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/data/repositories/hadith_lookups.dart';
import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_search_repository.dart';

class AhadithSearchRepositoryImpl extends AhadithSearchRepository {
  final AhadithArabicSearchLocalDataSource arabicSearchDataSource;
  final AhadithLocalDataSource ahadithLocalDataSource;
  final AhadithRemoteDataSource ahadithRemoteDataSource;
  final Map<String, Map<int, Chapter>> _bookLookupMaps;

  AhadithSearchRepositoryImpl({
    required this.arabicSearchDataSource,
    required this.ahadithLocalDataSource,
    required this.ahadithRemoteDataSource,
    required Map<String, dynamic> allChapters,
  }) : _bookLookupMaps = generateChapterLookups(allChapters);

  @override
  void initializeArabicBookSearch(String bookSlug) {
    arabicSearchDataSource.initBook(bookSlug);
  }

  @override
  Future<Either<Failure, List<Hadith>>> searchHadiths({
    required String query,
    required String bookSlug,
    required bool isDownloaded,
    HadithStatus? status,
    int? chapterId,
  }) async {
    if (AhadithHelpers.isArabic(query)) {
      final bookNumbers = await arabicSearchDataSource.getSearchedHadithsNumbers(
        query: query,
        status: status,
        chapterId: chapterId,
      );

      if (bookNumbers.isEmpty) return Right([]);

      final localResult =
          ahadithLocalDataSource.getAhadithByNumbers(bookNumbers, bookSlug);

      final List<Hadith> combinedResults = localResult.found;

      if (!isDownloaded && localResult.missing.isNotEmpty) {
        try {
          final remoteResults = await ahadithRemoteDataSource
              .getAhadithByNumbers(localResult.missing, bookSlug);
          combinedResults.addAll(remoteResults);
        } on DioException catch (e) {
          if (combinedResults.isEmpty) return left(UnknownFailure(e.toString()));
        }
      }

      // Safety net for any entity whose chapter/status slipped past the index
      // filter (e.g. a remote-fetched missing number).
      final filtered = combinedResults
          .where((h) => status == null || h.status == status)
          .where((h) => chapterId == null || h.chapterId == chapterId)
          .toList();

      return Right(AhadithHelpers.sortHadiths(filtered));
    } else {
      if (isDownloaded) {
        final ahadith = ahadithLocalDataSource.getSearchedHadiths(
          query,
          bookSlug,
          status: status,
          chapterId: chapterId,
        );
        return right(ahadith);
      } else {
        try {
          final chapterNumber = chapterId == null
              ? null
              : _bookLookupMaps[bookSlug]?[chapterId]?.chapterNumber;
          final ahadith = await ahadithRemoteDataSource.getSearchedHadiths(
            query,
            bookSlug,
            status: status == null ? null : hadithStatusApiValue[status],
            chapterNumber: chapterNumber,
          );
          return Right(ahadith);
        } on DioException catch (e) {
          return left(UnknownFailure(e.toString()));
        }
      }
    }
  }

  @override
  void dispose() {
    arabicSearchDataSource.clearCurrentBook();
  }
}
```

- [ ] **Step 5: Run the repo tests**

Run: `flutter test test/features/ahadith/ahadith_search_repository_impl_test.dart`
Expected: PASS (the three Arabic tests + the new online-English test). If the Arabic `when(() => arabic.getSearchedHadithsNumbers(query: any(named: 'query')))` stubs fail to match the new named params, update them to `getSearchedHadithsNumbers(query: any(named: 'query'), status: any(named: 'status'), chapterId: any(named: 'chapterId'))`.

- [ ] **Step 6: Commit**

```bash
git add lib/features/ahadith/domain/repositories/ahadith_search_repository.dart lib/features/ahadith/data/repositories/ahadith_search_repository_impl.dart test/features/ahadith/ahadith_search_repository_impl_test.dart
git commit -m "feat(ahadith): make search repository filter-aware across all paths"
```

---

## Task 5: Wire `allChapters` into the search repo in DI

**Files:**
- Modify: `lib/features/ahadith/ahadith_di.dart`

- [ ] **Step 1: Pass the chapters singleton to the search repo**

In `lib/features/ahadith/ahadith_di.dart`, inside `initAhadithSearch()`, update the `AhadithSearchRepository` registration:

```dart
  sl.registerLazySingleton<AhadithSearchRepository>(
    () => AhadithSearchRepositoryImpl(
      ahadithLocalDataSource: sl(),
      ahadithRemoteDataSource: sl(),
      arabicSearchDataSource: sl(),
      allChapters: sl(instanceName: 'chapters'),
    ),
  );
```

(The `'chapters'` singleton is already registered in `initAhadith()`, which runs before `initAhadithSearch()`.)

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/ahadith/ahadith_di.dart`
Expected: No errors.

- [ ] **Step 3: Commit**

```bash
git add lib/features/ahadith/ahadith_di.dart
git commit -m "chore(ahadith): inject chapters lookup into search repository"
```

---

## Task 6: Arabic search index — carry chapter + status, filter before cap

Enrich the index value from a bare string to `{t, c, s}` and filter by chapter/status before applying `kArabicSearchResultLimit`. Tolerate the old format defensively.

**Files:**
- Modify: `lib/features/ahadith/data/datasources/local/ahadith_arabic_search_local_data_source.dart`
- Test: `test/features/ahadith/arabic_search_index_test.dart`

- [ ] **Step 1: Write the failing test**

The current data source loads from a bundled zip, which is awkward to unit-test directly. Extract the pure matching logic into a testable top-level function `searchIndexEntries`, and test that.

```dart
// test/features/ahadith/arabic_search_index_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_arabic_search_local_data_source.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

void main() {
  // Normalized index: number -> {t: normalizedText, c: chapterId, s: status}
  final index = <String, ArabicIndexEntry>{
    '1': const ArabicIndexEntry(text: 'الصلاه فرض', chapterId: 5, status: HadithStatus.sahih),
    '2': const ArabicIndexEntry(text: 'الصلاه سنه', chapterId: 9, status: HadithStatus.sahih),
    '3': const ArabicIndexEntry(text: 'الصلاه فرض', chapterId: 5, status: HadithStatus.daeef),
  };

  test('filters by chapterId before capping', () {
    final result = searchIndexEntries(index, 'الصلاه', chapterId: 5, limit: 100);
    expect(result.toSet(), {'1', '3'});
  });

  test('filters by status', () {
    final result = searchIndexEntries(index, 'الصلاه', status: HadithStatus.daeef, limit: 100);
    expect(result, ['3']);
  });

  test('caps results after filtering', () {
    final result = searchIndexEntries(index, 'الصلاه', limit: 2);
    expect(result.length, 2);
  });

  test('parseIndexValue tolerates an old bare-string entry', () {
    final entry = parseIndexValue('نص قديم');
    expect(entry.text, 'نص قديم');
    expect(entry.chapterId, isNull);
    expect(entry.status, isNull);
  });
}
```

- [ ] **Step 2: Run the test to verify it fails**

Run: `flutter test test/features/ahadith/arabic_search_index_test.dart`
Expected: FAIL — `ArabicIndexEntry`, `searchIndexEntries`, `parseIndexValue` do not exist.

- [ ] **Step 3: Implement the enriched index model + logic**

Rewrite `lib/features/ahadith/data/datasources/local/ahadith_arabic_search_local_data_source.dart`:

```dart
import 'dart:convert';
import 'package:archive/archive.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quran_app/core/helper%20functions/ahadith_helpers.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

/// One entry in the per-book Arabic search index: normalized text plus the
/// chapter id and grade needed to filter matches before the result cap.
class ArabicIndexEntry {
  final String text;
  final int? chapterId;
  final HadithStatus? status;
  const ArabicIndexEntry({required this.text, this.chapterId, this.status});
}

/// Parses an index value, tolerating both the new object form
/// `{"t":..,"c":..,"s":..}` and the legacy bare-string form (text only).
ArabicIndexEntry parseIndexValue(dynamic value) {
  if (value is Map) {
    return ArabicIndexEntry(
      text: (value['t'] ?? '').toString(),
      chapterId: value['c'] is int ? value['c'] as int : null,
      status: _statusFromName(value['s']?.toString()),
    );
  }
  return ArabicIndexEntry(text: value.toString());
}

HadithStatus? _statusFromName(String? name) {
  if (name == null) return null;
  for (final s in HadithStatus.values) {
    if (s.name == name) return s;
  }
  return null;
}

/// Pure search over the parsed index: text-contains + optional chapter/grade,
/// filtered BEFORE [limit] so a chapter/grade is never truncated away.
List<String> searchIndexEntries(
  Map<String, ArabicIndexEntry> index,
  String normalizedQuery, {
  HadithStatus? status,
  int? chapterId,
  required int limit,
}) {
  return index.entries
      .where((e) => e.value.text.contains(normalizedQuery))
      .where((e) => status == null || e.value.status == status)
      .where((e) => chapterId == null || e.value.chapterId == chapterId)
      .map((e) => e.key)
      .take(limit)
      .toList();
}

class AhadithArabicSearchLocalDataSource {
  Map<String, ArabicIndexEntry>? _currentMapInMemory;
  Future<void>? _initFuture;

  Future<void> initBook(String bookSlug) {
    _initFuture = _loadIndex(bookSlug);
    return _initFuture!;
  }

  Future<void> _loadIndex(String bookSlug) async {
    final data = await rootBundle.load('assets/json/ahadith_indices.zip');
    final bytes = data.buffer.asUint8List();
    _currentMapInMemory =
        await compute(_parseZipInBackground, _ZipArgs(bytes, bookSlug));
  }

  Future<List<String>> getSearchedHadithsNumbers({
    required String query,
    HadithStatus? status,
    int? chapterId,
  }) async {
    try {
      await _initFuture;
    } catch (_) {
      return [];
    }
    final index = _currentMapInMemory;
    if (index == null) return [];
    final normalized = AhadithHelpers.cleanArabicQuery(query);
    return searchIndexEntries(
      index,
      normalized,
      status: status,
      chapterId: chapterId,
      limit: kArabicSearchResultLimit,
    );
  }

  void clearCurrentBook() {
    _currentMapInMemory = null;
    _initFuture = null;
  }
}

Map<String, ArabicIndexEntry> _parseZipInBackground(_ZipArgs args) {
  final archive = ZipDecoder().decodeBytes(args.bytes);
  final file = archive.findFile('${args.slug}.json');
  if (file == null) return {};

  final content = utf8.decode(file.content as List<int>);
  final Map<String, dynamic> decoded = jsonDecode(content);
  return decoded.map((key, value) => MapEntry(key, parseIndexValue(value)));
}

class _ZipArgs {
  final Uint8List bytes;
  final String slug;
  _ZipArgs(this.bytes, this.slug);
}
```

Add the import for `kArabicSearchResultLimit`:
```dart
import 'package:quran_app/core/constants/hadith_constants.dart';
```

- [ ] **Step 4: Run the test to verify it passes**

Run: `flutter test test/features/ahadith/arabic_search_index_test.dart`
Expected: PASS.

- [ ] **Step 5: Run the full ahadith suite (regression)**

Run: `flutter test test/features/ahadith/`
Expected: PASS. (Repo test mocks `getSearchedHadithsNumbers` — confirm the named-arg matchers from Task 4 Step 5 cover the new params.)

- [ ] **Step 6: Commit**

```bash
git add lib/features/ahadith/data/datasources/local/ahadith_arabic_search_local_data_source.dart test/features/ahadith/arabic_search_index_test.dart
git commit -m "feat(ahadith): enrich arabic search index with chapter/grade, filter before cap"
```

---

## Task 7: Regenerate the Arabic search index asset

Update the generator to write the new `{t, c, s}` value form and rebuild the bundled zip.

**Files:**
- Modify: `scripts/normalize_arabic_hadith.dart`
- Regenerate: `assets/json/ahadith_indices.zip`

- [ ] **Step 1: Update the generator to capture chapter id + status**

In `scripts/normalize_arabic_hadith.dart`, change the index value built in `crawlBook`. Replace the `Map<String, String> searchIndex = {};` declaration with `Map<String, dynamic> searchIndex = {};` and replace the inner loop body:

```dart
          for (var item in list) {
            String rawArabic = item['hadithArabic'] ?? "";
            final status = (item['status'] ?? '').toString().toLowerCase();
            // Normalize status to the app's enum names (sahih/hasan/daeef).
            final statusName = status == 'sahih'
                ? 'sahih'
                : status == 'hasan'
                    ? 'hasan'
                    : 'daeef';
            searchIndex[item['hadithNumber'].toString()] = {
              't': normalizeArabic(rawArabic),
              'c': item['chapter']?['id'],
              's': statusName,
            };
          }
```

- [ ] **Step 2: Run the generator**

Run (from repo root, requires the API to be reachable):
```bash
dart run scripts/normalize_arabic_hadith.dart
```
Expected: seven `<book>.json` files written in the working directory, each entry now an object `{t,c,s}`.

- [ ] **Step 3: Re-zip into the asset**

Zip the seven JSON files into `assets/json/ahadith_indices.zip` (entry names must be `<slug>.json`, e.g. `sahih-bukhari.json`). Using PowerShell:
```powershell
Compress-Archive -Path sahih-bukhari.json,sahih-muslim.json,al-tirmidhi.json,abu-dawood.json,ibn-e-majah.json,sunan-nasai.json,mishkat.json -DestinationPath assets/json/ahadith_indices.zip -Force
```
Then delete the loose `<book>.json` files from the repo root.

> **Verify (spec open item #2):** check the regenerated zip's size is acceptable as a bundled asset (compare against the previous size). If it grows substantially, consider shorter keys (already `t/c/s`) or dropping `s` (grade still filterable post-resolution for the downloaded path).

- [ ] **Step 4: Smoke-test the parse against the real asset**

Run: `flutter test test/features/ahadith/`
Expected: PASS. Then manually verify in-app (Task 9 covers UI): an Arabic search inside a selected chapter returns only that chapter's matches.

- [ ] **Step 5: Commit**

```bash
git add scripts/normalize_arabic_hadith.dart assets/json/ahadith_indices.zip
git commit -m "data(ahadith): regenerate arabic search index with chapter/grade"
```

---

## Task 8: Cubit — accept the filter and re-search on change

**Files:**
- Modify: `lib/features/ahadith/presentation/cubit/search_hadith_cubit.dart`

- [ ] **Step 1: Update the cubit**

Rewrite `lib/features/ahadith/presentation/cubit/search_hadith_cubit.dart`:

```dart
import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_search_repository.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/download_book_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/utils/hadith_list_filter.dart';

part 'search_hadith_state.dart';

class SearchHadithCubit extends Cubit<SearchHadithState> {
  final DownloadBookCubit downloadBookCubit;
  final AhadithSearchRepository ahadithSearchRepository;

  Timer? _debounce;
  String _lastQuery = '';
  String? _lastBookSlug;
  HadithListFilter _lastFilter = const HadithListFilter();

  SearchHadithCubit({
    required this.downloadBookCubit,
    required this.ahadithSearchRepository,
  }) : super(SearchHadithInitial());

  Future<void> searchAhadith(
    String query,
    String bookSlug, {
    HadithListFilter filter = const HadithListFilter(),
  }) async {
    if (_debounce?.isActive ?? false) _debounce!.cancel();

    _lastQuery = query;
    _lastBookSlug = bookSlug;
    _lastFilter = filter;

    if (query.trim().isEmpty) {
      emit(SearchHadithInitial());
      return;
    }

    _debounce = Timer(const Duration(milliseconds: 300), () async {
      emit(SearchHadithLoading());

      final isDownloaded =
          downloadBookCubit.state.downloadedBooks.contains(bookSlug);

      final result = await ahadithSearchRepository.searchHadiths(
        query: query,
        bookSlug: bookSlug,
        isDownloaded: isDownloaded,
        status: filter.status,
        chapterId: filter.chapterId,
      );

      if (isClosed) return;
      result.fold(
        (failure) => emit(SearchHadithError(failure.message)),
        (ahadithList) => emit(SearchHadithLoaded(ahadithList)),
      );
    });
  }

  /// Re-runs the current query under a new filter (called when the user changes
  /// the filter while a search is active). No-op if there is no active query.
  void reapplyFilter(HadithListFilter filter) {
    if (_lastBookSlug == null || _lastQuery.trim().isEmpty) {
      _lastFilter = filter;
      return;
    }
    searchAhadith(_lastQuery, _lastBookSlug!, filter: filter);
  }

  void initializeArabicBookSearch(String bookSlug) {
    ahadithSearchRepository.initializeArabicBookSearch(bookSlug);
  }

  @override
  Future<void> close() {
    _debounce?.cancel();
    ahadithSearchRepository.dispose();
    return super.close();
  }
}
```

(The added `isClosed` guard before `emit` also fixes a latent late-emit risk.)

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/ahadith/presentation/cubit/search_hadith_cubit.dart`
Expected: No errors (the view caller is updated in Task 9).

- [ ] **Step 3: Commit**

```bash
git add lib/features/ahadith/presentation/cubit/search_hadith_cubit.dart
git commit -m "feat(ahadith): search cubit accepts filter and re-searches on change"
```

---

## Task 9: View — re-search on filter change

**Files:**
- Modify: `lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart`

- [ ] **Step 1: Pass the filter into search and re-search on filter change**

In `lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart`, update `_onQueryChanged` and `_updateFilter`:

```dart
  void _onQueryChanged(String value) {
    setState(() => _query = value);
    context
        .read<SearchHadithCubit>()
        .searchAhadith(value, widget.bookSlug, filter: _filter);
  }

  void _updateFilter(HadithListFilter filter) {
    setState(() => _filter = filter);
    final isDownloaded = context
        .read<DownloadBookCubit>()
        .state
        .downloadedBooks
        .contains(widget.bookSlug);
    context.read<AhadithCubit>().applyFilter(filter, isDownloaded: isDownloaded);
    // Keep an active search in sync with the filter.
    context.read<SearchHadithCubit>().reapplyFilter(filter);
  }
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart`
Expected: No errors (the redundant `applyHadithFilters` in `_buildSearchResults` stays as a safety net).

- [ ] **Step 3: Commit**

```bash
git add lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart
git commit -m "feat(ahadith): re-run search when the active filter changes"
```

---

## Task 10: Chapter picker — small searchable bottom sheet

A second bottom sheet, opened from the filter sheet's "Change", that searches chapters by number / Arabic / English and returns the chosen chapter id (or `null` for "All chapters").

**Files:**
- Create: `lib/features/ahadith/presentation/pages/widgets/chapter_picker_sheet.dart`

- [ ] **Step 1: Create the picker widget**

```dart
// lib/features/ahadith/presentation/pages/widgets/chapter_picker_sheet.dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/generated/l10n.dart';

/// Small, searchable chapter picker shown as a bottom sheet over the filter
/// sheet. Returns the selected chapter id via [Navigator.pop], or `null` for
/// "All chapters". Returns nothing (dismissed) if the user swipes it away.
class ChapterPickerSheet extends StatefulWidget {
  const ChapterPickerSheet({
    super.key,
    required this.chapters,
    required this.selectedChapterId,
  });

  final List<Chapter> chapters;
  final int? selectedChapterId;

  /// Opens the picker. Resolves to `(true, id)` when the user picked a chapter
  /// (id may be null for "All chapters"), or `null` when dismissed.
  static Future<({int? chapterId})?> show(
    BuildContext context, {
    required List<Chapter> chapters,
    required int? selectedChapterId,
  }) {
    return showModalBottomSheet<({int? chapterId})>(
      context: context,
      backgroundColor: context.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChapterPickerSheet(
        chapters: chapters,
        selectedChapterId: selectedChapterId,
      ),
    );
  }

  @override
  State<ChapterPickerSheet> createState() => _ChapterPickerSheetState();
}

class _ChapterPickerSheetState extends State<ChapterPickerSheet> {
  String _query = '';

  List<Chapter> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.chapters;
    return widget.chapters.where((c) {
      return c.chapterNumber.toString().contains(q) ||
          c.chapterEnglish.toLowerCase().contains(q) ||
          c.chapterArabic.contains(_query.trim());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final filtered = _filtered;
    final sheetHeight = MediaQuery.of(context).size.height * 0.6;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  S.of(context).filter_chapter_label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(fontSize: 14, color: scheme.onSurface),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: S.of(context).filter_chapter_label,
                    prefixIcon: HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 40),
                    filled: true,
                    fillColor: scheme.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      _PickerRow(
                        label: S.of(context).filter_all_chapters,
                        selected: widget.selectedChapterId == null,
                        onTap: () =>
                            Navigator.of(context).pop((chapterId: null)),
                      ),
                      for (final c in filtered)
                        _PickerRow(
                          label:
                              '${c.chapterNumber}. ${isRtl ? c.chapterArabic : c.chapterEnglish}',
                          selected: widget.selectedChapterId == c.id,
                          onTap: () =>
                              Navigator.of(context).pop((chapterId: c.id)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
```

- [ ] **Step 2: Verify it compiles**

Run: `flutter analyze lib/features/ahadith/presentation/pages/widgets/chapter_picker_sheet.dart`
Expected: No errors. (If `filter_chapter_label`/`filter_all_chapters` keys differ, reuse the exact keys already used in `_FilterSheet`.)

- [ ] **Step 3: Commit**

```bash
git add lib/features/ahadith/presentation/pages/widgets/chapter_picker_sheet.dart
git commit -m "feat(ahadith): searchable chapter picker bottom sheet"
```

---

## Task 11: Rework the filter sheet — compact, stateful, grade pills + picker

Replace the flat chapter `ListView` in `_FilterSheet` with a stateful compact sheet: grade pills (synced via `_filter`) + a selected-chapter card whose "Change" opens the picker.

**Files:**
- Modify: `lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart`

- [ ] **Step 1: Pass available statuses into the sheet and open it**

In `_openFilterSheet()`, capture the available statuses and pass them in:

```dart
  Future<void> _openFilterSheet() async {
    final cubit = context.read<AhadithCubit>();
    final chapters = cubit.chapters;
    final statuses = cubit.availableStatuses;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _FilterSheet(
        chapters: chapters,
        statuses: statuses,
        filter: _filter,
        onChanged: _updateFilter,
      ),
    );
  }
```

- [ ] **Step 2: Replace `_FilterSheet` with a stateful compact sheet**

Replace the entire `_FilterSheet` class (and the now-unused `_ChapterOption` class) in `ahadith_list_view.dart` with:

```dart
class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.chapters,
    required this.statuses,
    required this.filter,
    required this.onChanged,
  });

  final List<Chapter> chapters;
  final Set<HadithStatus> statuses;
  final HadithListFilter filter;
  final ValueChanged<HadithListFilter> onChanged;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late HadithListFilter _filter = widget.filter;

  void _apply(HadithListFilter next) {
    setState(() => _filter = next);
    widget.onChanged(next);
  }

  Chapter? get _selectedChapter {
    if (_filter.chapterId == null) return null;
    for (final c in widget.chapters) {
      if (c.id == _filter.chapterId) return c;
    }
    return null;
  }

  Future<void> _openChapterPicker() async {
    final result = await ChapterPickerSheet.show(
      context,
      chapters: widget.chapters,
      selectedChapterId: _filter.chapterId,
    );
    if (result == null) return; // dismissed
    _apply(_filter.withChapter(result.chapterId));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final selected = _selectedChapter;
    final hasGrades = widget.statuses.length > 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context).filters_title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _apply(const HadithListFilter());
                    Navigator.of(context).pop();
                  },
                  child: Text(S.of(context).filter_clear),
                ),
              ],
            ),
            if (hasGrades) ...[
              const SizedBox(height: 6),
              Text(
                S.of(context).filter_status_label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in HadithStatus.values)
                    if (widget.statuses.contains(status))
                      _GradePill(
                        label: statusLabel(context, status),
                        color: statusColor(status),
                        selected: _filter.status == status,
                        onTap: () => _apply(_filter.toggleStatus(status)),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              S.of(context).filter_chapter_label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: widget.chapters.isEmpty ? null : _openChapterPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected == null
                            ? S.of(context).filter_all_chapters
                            : '${selected.chapterNumber}. ${isRtl ? selected.chapterArabic : selected.chapterEnglish}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      isRtl ? Icons.chevron_left : Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradePill extends StatelessWidget {
  const _GradePill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : scheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
```

Add the import near the other widget imports in `ahadith_list_view.dart`:
```dart
import 'package:quran_app/features/ahadith/presentation/pages/widgets/chapter_picker_sheet.dart';
```

> `statusLabel` / `statusColor` are already used by `_StatusChipsRow` in this file — reuse them. `filters_title`, `filter_clear`, `filter_chapter_label`, `filter_all_chapters` already exist. `filter_status_label` may need adding — see Step 3.

- [ ] **Step 3: Add the `filter_status_label` string if missing**

Check `lib/l10n/intl_en.arb` and `intl_ar.arb` for `filter_status_label`. If absent, add it (en: `"Grade"`, ar: `"الدرجة"`) following the existing ARB entry format, then regenerate:

```bash
dart run intl_utils:generate
```

(Per project memory, run this to regenerate `generated/l10n.dart` from the CLI.)

- [ ] **Step 4: Verify it compiles**

Run: `flutter analyze lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart`
Expected: No errors.

- [ ] **Step 5: Commit**

```bash
git add lib/features/ahadith/presentation/pages/widgets/ahadith_list_view.dart lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated/
git commit -m "feat(ahadith): compact filter sheet with grade pills + chapter picker"
```

---

## Task 12: Full regression + manual verification

- [ ] **Step 1: Run the whole ahadith test suite**

Run: `flutter test test/features/ahadith/`
Expected: PASS.

- [ ] **Step 2: Static analysis**

Run: `flutter analyze`
Expected: No new errors/warnings in touched files.

- [ ] **Step 3: Manual verification (per spec "Desired Behavior")**

Launch the app (use the `/run` skill or `flutter run`) and confirm on a hadith book screen:
- Search with **no** filter returns matches as before.
- Select a **chapter** in the picker, then search → results are limited to that chapter and are **complete** (not cut off at a page boundary). Try a downloaded book and a non-downloaded book.
- Select a **grade** pill (in the sheet and via the main-screen chip row) → both stay in sync; search respects it.
- An **Arabic** query within a selected chapter returns only that chapter's matches.
- Picking a chapter in the picker returns to the **compact sheet** with the selection shown; "Clear all" resets both grade and chapter.

- [ ] **Step 4: Commit any fixes, then finish the branch**

Use `superpowers:finishing-a-development-branch` to decide merge/PR.

---

## Self-Review Notes

- **Spec coverage:** Part 1 (filter-aware search) → Tasks 2–5, 8, 9. Part 2 (sheet redesign) → Tasks 10, 11. Part 3 (Arabic index) → Tasks 6, 7. Shared groundwork → Task 1. Verification → Task 12.
- **Layering correction vs spec:** the repo/data layer takes primitive `status`/`chapterId` (not the presentation `HadithListFilter`); the cubit unpacks the filter. Recorded in the header.
- **Spec open items** (API accepts `status`+`chapter` with `hadithEnglish`; regenerated asset size) are called out inline in Tasks 3 and 7 to verify during implementation.
