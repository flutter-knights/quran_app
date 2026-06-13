# Mushaf Control Surface — Phase 3 (Page Bookmarks + Ribbon) Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add real page-level bookmarks — a "Save page" toggle, a physical-mushaf **silk ribbon** on saved pages, a surah/ayah **description**, and a "Pages" section in the Bookmarks screen — as a feature parallel to the untouched ayah bookmarks.

**Architecture:** Mirror the existing ayah-bookmark stack (Hive box + repository + use cases + Cubit, app-wide provider) for an `int`-keyed `PageBookmarkCubit`. A pure `describePage()` util derives the label from `quran.getPageData`. A `MushafPageRibbon` painter renders in `MushafPageView` when its page is saved. The Phase-1 browse-bar Save button is repointed from the ayah `BookmarkCubit` to `PageBookmarkCubit`.

**Tech Stack:** Flutter, `flutter_bloc` (Cubit), `hive`, `get_it`, `dartz`, `quran` package, `mocktail`, `flutter_test`. FVM-pinned Flutter 3.38.1.

> **Scope/deps:** Phase 3 of Workstream A. **Depends on Phase 1** (it repoints the browse-bar Save button created there). Independent of Phase 2.
> **Test caveat:** never run the full `fvm flutter test`; scope to `test/features/...`. Never `git add -A`.

---

## File structure

| File | Responsibility | Action |
|---|---|---|
| `lib/features/bookmarks/data/datasources/local/page_bookmark_local_data_source.dart` | Hive `page_bookmarks` box; `Set<int>` get + toggle | Create |
| `lib/features/bookmarks/domain/repositories/page_bookmark_repository.dart` | Abstract repo | Create |
| `lib/features/bookmarks/data/repositories/page_bookmark_repository_impl.dart` | Impl, exception→failure | Create |
| `lib/features/bookmarks/domain/usecases/get_page_bookmarks.dart` · `toggle_page_bookmark.dart` | Use cases | Create |
| `lib/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart` · `page_bookmark_state.dart` | State mgmt | Create |
| `lib/features/bookmarks/presentation/utils/page_description.dart` | `describePage()` | Create |
| `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon.dart` | Ribbon painter | Create |
| `lib/features/bookmarks/bookmarks_di.dart` | Register page-bookmark deps | Modify |
| `lib/config/hive_config.dart` | Open `page_bookmarks` box | Modify |
| `lib/main.dart` | Provide `PageBookmarkCubit` app-wide | Modify |
| `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart` | Render ribbon | Modify |
| `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` | Repoint Save → `PageBookmarkCubit` | Modify |
| `lib/features/bookmarks/presentation/pages/bookmarks_page.dart` | "Pages" section | Modify |
| `lib/l10n/intl_en.arb` · `intl_ar.arb` | `bookmarks_pages_section`, `undo`, `pageRemovedFromBookmarks` | Modify |

---

### Task 1: Page-bookmark local data source

**Files:**
- Create: `lib/features/bookmarks/data/datasources/local/page_bookmark_local_data_source.dart`
- Test: `test/features/bookmarks/data/datasources/page_bookmark_local_data_source_test.dart`

- [ ] **Step 1: Write the failing test** (Hive in-memory via a temp dir)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quran_app/features/bookmarks/data/datasources/local/page_bookmark_local_data_source.dart';

void main() {
  late Box<List> box;
  late PageBookmarkLocalDataSource ds;

  setUp(() async {
    Hive.init('./.dart_tool/hive_test_page_bm');
    box = await Hive.openBox<List>('page_bookmarks_test');
    await box.clear();
    ds = PageBookmarkLocalDataSource(box: box);
  });

  tearDown(() async {
    await box.clear();
    await box.close();
  });

  test('starts empty', () {
    expect(ds.getAll(), <int>{});
  });

  test('toggle adds then removes a page', () async {
    expect(await ds.toggle(42), true);
    expect(ds.getAll(), {42});
    expect(await ds.toggle(42), false);
    expect(ds.getAll(), <int>{});
  });

  test('keeps multiple pages', () async {
    await ds.toggle(3);
    await ds.toggle(100);
    expect(ds.getAll(), {3, 100});
  });
}
```

- [ ] **Step 2: Run, verify it fails**

Run: `fvm flutter test test/features/bookmarks/data/datasources/page_bookmark_local_data_source_test.dart`
Expected: FAIL — class missing.

- [ ] **Step 3: Implement**

`lib/features/bookmarks/data/datasources/local/page_bookmark_local_data_source.dart`:
```dart
import 'package:hive/hive.dart';

import '../../../../../core/errors/exceptions.dart';

/// Page-level bookmarks. Stored as a `List<int>` of page numbers under one key,
/// mirroring the ayah `BookmarkLocalDataSource` shape.
class PageBookmarkLocalDataSource {
  PageBookmarkLocalDataSource({required this.box});
  final Box<List> box;

  static const _key = 'all';

  Set<int> getAll() {
    final raw = box.get(_key);
    if (raw == null) return <int>{};
    final result = <int>{};
    for (final entry in raw) {
      if (entry is int) {
        result.add(entry);
      } else {
        final parsed = int.tryParse('$entry');
        if (parsed != null) result.add(parsed);
      }
    }
    return result;
  }

  Future<bool> toggle(int page) async {
    try {
      final current = (box.get(_key) ?? <int>[])
          .map((e) => e is int ? e : int.parse('$e'))
          .toList(growable: true);
      final wasPresent = current.remove(page);
      if (!wasPresent) current.add(page);
      await box.put(_key, current);
      return !wasPresent;
    } catch (e) {
      throw CacheException('page bookmark toggle failed: $e');
    }
  }
}
```

- [ ] **Step 4: Run, verify it passes**

Run: `fvm flutter test test/features/bookmarks/data/datasources/page_bookmark_local_data_source_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/data/datasources/local/page_bookmark_local_data_source.dart test/features/bookmarks/data/datasources/page_bookmark_local_data_source_test.dart
git commit -m "feat(bookmarks): page-bookmark local data source

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 2: Page-bookmark repository (interface + impl)

**Files:**
- Create: `lib/features/bookmarks/domain/repositories/page_bookmark_repository.dart`
- Create: `lib/features/bookmarks/data/repositories/page_bookmark_repository_impl.dart`
- Test: `test/features/bookmarks/data/repositories/page_bookmark_repository_impl_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/data/datasources/local/page_bookmark_local_data_source.dart';
import 'package:quran_app/features/bookmarks/data/repositories/page_bookmark_repository_impl.dart';

class _MockDs extends Mock implements PageBookmarkLocalDataSource {}

void main() {
  late _MockDs ds;
  late PageBookmarkRepositoryImpl repo;

  setUp(() {
    ds = _MockDs();
    repo = PageBookmarkRepositoryImpl(dataSource: ds);
  });

  test('getAll returns Right(set)', () async {
    when(() => ds.getAll()).thenReturn({1, 2});
    expect(await repo.getAll(), const Right<Failure, Set<int>>({1, 2}));
  });

  test('toggle returns Right(true) when added', () async {
    when(() => ds.toggle(5)).thenAnswer((_) async => true);
    expect(await repo.toggle(5), const Right<Failure, bool>(true));
  });

  test('maps CacheException to Left(CacheFailure)', () async {
    when(() => ds.toggle(5)).thenThrow(const CacheException('boom'));
    final r = await repo.toggle(5);
    expect(r.isLeft(), true);
    r.fold((f) => expect(f, isA<CacheFailure>()), (_) {});
  });
}
```

- [ ] **Step 2: Run, verify it fails**

Run: `fvm flutter test test/features/bookmarks/data/repositories/page_bookmark_repository_impl_test.dart`
Expected: FAIL — classes missing.

- [ ] **Step 3: Implement the interface + impl**

`lib/features/bookmarks/domain/repositories/page_bookmark_repository.dart`:
```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';

abstract class PageBookmarkRepository {
  Future<Either<Failure, Set<int>>> getAll();
  Future<Either<Failure, bool>> toggle(int page);
}
```

`lib/features/bookmarks/data/repositories/page_bookmark_repository_impl.dart`:
```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure.dart';
import '../../domain/repositories/page_bookmark_repository.dart';
import '../datasources/local/page_bookmark_local_data_source.dart';

class PageBookmarkRepositoryImpl implements PageBookmarkRepository {
  PageBookmarkRepositoryImpl({required this.dataSource});
  final PageBookmarkLocalDataSource dataSource;

  @override
  Future<Either<Failure, Set<int>>> getAll() async {
    try {
      return Right(dataSource.getAll());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> toggle(int page) async {
    try {
      return Right(await dataSource.toggle(page));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
```

- [ ] **Step 4: Run, verify it passes**

Run: `fvm flutter test test/features/bookmarks/data/repositories/page_bookmark_repository_impl_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/domain/repositories/page_bookmark_repository.dart lib/features/bookmarks/data/repositories/page_bookmark_repository_impl.dart test/features/bookmarks/data/repositories/page_bookmark_repository_impl_test.dart
git commit -m "feat(bookmarks): page-bookmark repository

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 3: Use cases + state

**Files:**
- Create: `lib/features/bookmarks/domain/usecases/get_page_bookmarks.dart`
- Create: `lib/features/bookmarks/domain/usecases/toggle_page_bookmark.dart`
- Create: `lib/features/bookmarks/presentation/cubit/page_bookmark_state.dart`
- Test: `test/features/bookmarks/presentation/cubit/page_bookmark_state_test.dart`

- [ ] **Step 1: Write the failing test** (state semantics)

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_state.dart';

void main() {
  test('contains reflects the page set', () {
    const s = PageBookmarkState(pages: {3, 7}, loaded: true);
    expect(s.contains(3), true);
    expect(s.contains(4), false);
  });

  test('copyWith can clear error with explicit null', () {
    const s = PageBookmarkState(loaded: true, error: 'x');
    expect(s.copyWith(error: null).error, isNull);
    expect(s.copyWith(loaded: true).error, 'x'); // unspecified keeps old
  });
}
```

- [ ] **Step 2: Run, verify it fails**

Run: `fvm flutter test test/features/bookmarks/presentation/cubit/page_bookmark_state_test.dart`
Expected: FAIL — class missing.

- [ ] **Step 3: Implement use cases + state**

`lib/features/bookmarks/domain/usecases/get_page_bookmarks.dart`:
```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/page_bookmark_repository.dart';

class GetPageBookmarks {
  GetPageBookmarks(this.repository);
  final PageBookmarkRepository repository;

  Future<Either<Failure, Set<int>>> call() => repository.getAll();
}
```

`lib/features/bookmarks/domain/usecases/toggle_page_bookmark.dart`:
```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/page_bookmark_repository.dart';

class TogglePageBookmark {
  TogglePageBookmark(this.repository);
  final PageBookmarkRepository repository;

  Future<Either<Failure, bool>> call(int page) => repository.toggle(page);
}
```

`lib/features/bookmarks/presentation/cubit/page_bookmark_state.dart`:
```dart
import 'package:equatable/equatable.dart';

class PageBookmarkState extends Equatable {
  final Set<int> pages;
  final bool loaded;
  final String? error;

  const PageBookmarkState({
    this.pages = const {},
    this.loaded = false,
    this.error,
  });

  PageBookmarkState copyWith({
    Set<int>? pages,
    bool? loaded,
    Object? error = _sentinel,
  }) {
    return PageBookmarkState(
      pages: pages ?? this.pages,
      loaded: loaded ?? this.loaded,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  bool contains(int page) => pages.contains(page);

  @override
  List<Object?> get props => [pages, loaded, error];
}

const Object _sentinel = Object();
```

- [ ] **Step 4: Run, verify it passes**

Run: `fvm flutter test test/features/bookmarks/presentation/cubit/page_bookmark_state_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/domain/usecases/get_page_bookmarks.dart lib/features/bookmarks/domain/usecases/toggle_page_bookmark.dart lib/features/bookmarks/presentation/cubit/page_bookmark_state.dart test/features/bookmarks/presentation/cubit/page_bookmark_state_test.dart
git commit -m "feat(bookmarks): page-bookmark use cases + state

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 4: `PageBookmarkCubit`

**Files:**
- Create: `lib/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart`
- Test: `test/features/bookmarks/presentation/cubit/page_bookmark_cubit_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/get_page_bookmarks.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/toggle_page_bookmark.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart';

class _MockGet extends Mock implements GetPageBookmarks {}
class _MockToggle extends Mock implements TogglePageBookmark {}

void main() {
  late _MockGet get;
  late _MockToggle toggle;

  setUp(() {
    get = _MockGet();
    toggle = _MockToggle();
  });

  test('loads existing bookmarks on creation', () async {
    when(() => get.call()).thenAnswer((_) async => const Right({3, 9}));
    final cubit = PageBookmarkCubit(getPageBookmarks: get, togglePageBookmark: toggle);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.loaded, true);
    expect(cubit.state.pages, {3, 9});
    await cubit.close();
  });

  test('toggle adds a page to the set', () async {
    when(() => get.call()).thenAnswer((_) async => const Right(<int>{}));
    when(() => toggle.call(42)).thenAnswer((_) async => const Right(true));
    final cubit = PageBookmarkCubit(getPageBookmarks: get, togglePageBookmark: toggle);
    await Future<void>.delayed(Duration.zero);
    await cubit.toggle(42);
    expect(cubit.state.pages, {42});
    await cubit.close();
  });

  test('toggle removes a page when now unsaved', () async {
    when(() => get.call()).thenAnswer((_) async => const Right({42}));
    when(() => toggle.call(42)).thenAnswer((_) async => const Right(false));
    final cubit = PageBookmarkCubit(getPageBookmarks: get, togglePageBookmark: toggle);
    await Future<void>.delayed(Duration.zero);
    await cubit.toggle(42);
    expect(cubit.state.pages, <int>{});
    await cubit.close();
  });
}
```

- [ ] **Step 2: Run, verify it fails**

Run: `fvm flutter test test/features/bookmarks/presentation/cubit/page_bookmark_cubit_test.dart`
Expected: FAIL — class missing.

- [ ] **Step 3: Implement the cubit**

`lib/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart`:
```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/usecases/get_page_bookmarks.dart';
import '../../domain/usecases/toggle_page_bookmark.dart';
import 'page_bookmark_state.dart';

class PageBookmarkCubit extends Cubit<PageBookmarkState> {
  PageBookmarkCubit({
    required this.getPageBookmarks,
    required this.togglePageBookmark,
  }) : super(const PageBookmarkState()) {
    _load();
  }

  final GetPageBookmarks getPageBookmarks;
  final TogglePageBookmark togglePageBookmark;

  Future<void> _load() async {
    final result = await getPageBookmarks();
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(loaded: true, error: failure.message)),
      (set) => emit(state.copyWith(loaded: true, pages: set, error: null)),
    );
  }

  Future<void> toggle(int page) async {
    if (!state.loaded) return;
    final result = await togglePageBookmark(page);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (nowSaved) {
        final next = Set<int>.from(state.pages);
        if (nowSaved) {
          next.add(page);
        } else {
          next.remove(page);
        }
        emit(state.copyWith(pages: next, error: null));
      },
    );
  }
}
```

- [ ] **Step 4: Run, verify it passes**

Run: `fvm flutter test test/features/bookmarks/presentation/cubit/page_bookmark_cubit_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart test/features/bookmarks/presentation/cubit/page_bookmark_cubit_test.dart
git commit -m "feat(bookmarks): PageBookmarkCubit

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 5: Wire DI, Hive box, and app-wide provider

**Files:**
- Modify: `lib/config/hive_config.dart`
- Modify: `lib/features/bookmarks/bookmarks_di.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Open the Hive box**

In `lib/config/hive_config.dart`, after the `ayah_bookmarks` open (line 20), add:
```dart
  await Hive.openBox<List>('page_bookmarks');
```

- [ ] **Step 2: Register dependencies**

In `lib/features/bookmarks/bookmarks_di.dart`, add imports:
```dart
import 'data/datasources/local/page_bookmark_local_data_source.dart';
import 'data/repositories/page_bookmark_repository_impl.dart';
import 'domain/repositories/page_bookmark_repository.dart';
import 'domain/usecases/get_page_bookmarks.dart';
import 'domain/usecases/toggle_page_bookmark.dart';
import 'presentation/cubit/page_bookmark_cubit.dart';
```
And inside `initBookmarks()` (after the existing registrations) add:
```dart
  sl.registerLazySingleton<PageBookmarkLocalDataSource>(
    () => PageBookmarkLocalDataSource(box: Hive.box<List>('page_bookmarks')),
  );
  sl.registerLazySingleton<PageBookmarkRepository>(
    () => PageBookmarkRepositoryImpl(dataSource: sl<PageBookmarkLocalDataSource>()),
  );
  sl.registerLazySingleton<GetPageBookmarks>(
    () => GetPageBookmarks(sl<PageBookmarkRepository>()),
  );
  sl.registerLazySingleton<TogglePageBookmark>(
    () => TogglePageBookmark(sl<PageBookmarkRepository>()),
  );
  sl.registerLazySingleton<PageBookmarkCubit>(
    () => PageBookmarkCubit(
      getPageBookmarks: sl<GetPageBookmarks>(),
      togglePageBookmark: sl<TogglePageBookmark>(),
    ),
  );
```

- [ ] **Step 3: Provide the cubit app-wide**

In `lib/main.dart`, find the `MultiBlocProvider` `providers:` list containing `BlocProvider(create: (_) => sl<BookmarkCubit>())` (~line 80) and add directly after it:
```dart
        BlocProvider(create: (_) => sl<PageBookmarkCubit>()),
```
Add the import at the top of `main.dart`:
```dart
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart';
```

- [ ] **Step 4: Analyze (DI wiring compiles)**

Run: `fvm flutter analyze lib/features/bookmarks lib/config/hive_config.dart lib/main.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/config/hive_config.dart lib/features/bookmarks/bookmarks_di.dart lib/main.dart
git commit -m "feat(bookmarks): register page bookmarks (DI, Hive box, provider)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 6: `describePage()` util

**Files:**
- Create: `lib/features/bookmarks/presentation/utils/page_description.dart`
- Test: `test/features/bookmarks/presentation/utils/page_description_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/page_description.dart';

void main() {
  test('page 1 (Al-Fatiha) — English', () {
    // page 1 = basmala marker + Al-Fatiha 1–7; basmala is skipped.
    expect(describePage(1, localeCode: 'en'), 'Al-Fatihah 1–7');
  });

  test('page 1 — Arabic uses Arabic-Indic numerals', () {
    expect(describePage(1, localeCode: 'ar'), contains('١'));
  });

  test('last page (604) joins multiple surahs', () {
    // 604 = Al-Ikhlas, Al-Falaq, An-Nas.
    final d = describePage(604, localeCode: 'en');
    expect(d.split(',').length, 3);
  });
}
```

> NOTE: `quran.getSurahName(1)` returns `"Al-Fatihah"`. If the package's exact spelling differs, adjust the page-1 expectation in Step 1 to the value the package returns (run the test once to see the actual string) — do not change the implementation.

- [ ] **Step 2: Run, verify it fails**

Run: `fvm flutter test test/features/bookmarks/presentation/utils/page_description_test.dart`
Expected: FAIL — function missing.

- [ ] **Step 3: Implement**

`lib/features/bookmarks/presentation/utils/page_description.dart`:
```dart
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';

/// Human-readable description of the surah(s) + ayah range(s) on a Mushaf page,
/// e.g. "Al-Baqarah 30–48" / "البقرة ٣٠–٤٨". Skips the basmala pseudo-range
/// (`start == end == 0`). Numerals follow [localeCode] ('ar' → Arabic-Indic).
String describePage(int page, {required String localeCode}) {
  final data = quran.getPageData(page).cast<Map>();
  final parts = <String>[];
  for (final e in data) {
    final start = e['start'] as int;
    final end = e['end'] as int;
    if (start == 0 && end == 0) continue; // basmala marker
    final surah = e['surah'] as int;
    final name = localeCode == 'ar'
        ? quran.getSurahNameArabic(surah)
        : quran.getSurahName(surah);
    final s = start.toString().toIndicNumerals(localeCode);
    final en = end.toString().toIndicNumerals(localeCode);
    parts.add(start == end ? '$name $s' : '$name $s–$en');
  }
  if (parts.isEmpty) {
    final surah = data.isNotEmpty ? data.first['surah'] as int : 1;
    return localeCode == 'ar'
        ? quran.getSurahNameArabic(surah)
        : quran.getSurahName(surah);
  }
  return parts.join(localeCode == 'ar' ? '، ' : ', ');
}
```

- [ ] **Step 4: Run, verify it passes** (adjust the page-1 literal if the package spelling differs)

Run: `fvm flutter test test/features/bookmarks/presentation/utils/page_description_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/presentation/utils/page_description.dart test/features/bookmarks/presentation/utils/page_description_test.dart
git commit -m "feat(bookmarks): describePage() page → surah/ayah label

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 7: `MushafPageRibbon` widget

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon.dart`
- Test: `test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon_test.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon.dart';

void main() {
  testWidgets('renders and fires onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(
        body: Stack(
          children: [
            MushafPageRibbon(color: Colors.red, onTap: () => taps++),
          ],
        ),
      ),
    ));
    expect(find.byKey(const ValueKey('mushaf-page-ribbon')), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('mushaf-page-ribbon')));
    expect(taps, 1);
  });
}
```

- [ ] **Step 2: Run, verify it fails**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon_test.dart`
Expected: FAIL — class missing.

- [ ] **Step 3: Implement** (a `PositionedDirectional` Stack child painting a forked silk ribbon)

`lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon.dart`:
```dart
import 'package:flutter/material.dart';

/// A silk bookmark ribbon hanging from the top-trailing corner of a saved
/// page. Must be a child of a [Stack]. Tapping it removes the page bookmark.
class MushafPageRibbon extends StatelessWidget {
  const MushafPageRibbon({super.key, required this.color, required this.onTap});

  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PositionedDirectional(
      top: 0,
      end: 18,
      child: GestureDetector(
        key: const ValueKey('mushaf-page-ribbon'),
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: CustomPaint(
          size: const Size(18, 46),
          painter: _RibbonPainter(color),
        ),
      ),
    );
  }
}

class _RibbonPainter extends CustomPainter {
  _RibbonPainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final fill = Paint()..color = color;
    final shadow = Paint()
      ..color = Colors.black.withValues(alpha: 0.20)
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    final path = Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(size.width, size.height)
      ..lineTo(size.width / 2, size.height - 10) // forked notch
      ..lineTo(0, size.height)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 1)), shadow);
    canvas.drawPath(path, fill);
  }

  @override
  bool shouldRepaint(_RibbonPainter old) => old.color != color;
}
```

- [ ] **Step 4: Run, verify it passes**

Run: `fvm flutter test test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon.dart test/features/surah/presentation/pages/mushaf/widgets/mushaf_page_ribbon_test.dart
git commit -m "feat(mushaf): silk page-bookmark ribbon widget

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 8: Render the ribbon on saved pages + l10n strings

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`
- Modify: `lib/l10n/intl_en.arb`, `lib/l10n/intl_ar.arb`

- [ ] **Step 1: Add l10n keys**

`intl_en.arb` — add:
```json
  "undo": "Undo",
  "pageRemovedFromBookmarks": "Removed from bookmarks",
```
`intl_ar.arb` — add:
```json
  "undo": "تراجع",
  "pageRemovedFromBookmarks": "أزيلت من المحفوظات",
```
Regenerate l10n (IDE save or `fvm flutter gen-l10n`).

- [ ] **Step 2: Add imports + a ribbon child to the page Stack**

In `mushaf_page_view.dart`, add imports:
```dart
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_state.dart';
import 'package:quran_app/generated/l10n.dart';
import 'mushaf_page_ribbon.dart';
```
Inside the `Stack`'s `children`, **after** the gesture `Positioned.fill` (i.e. above the printed chrome so the ribbon is tappable), add:
```dart
                  BlocBuilder<PageBookmarkCubit, PageBookmarkState>(
                    buildWhen: (a, b) =>
                        a.contains(widget.pageNumber) !=
                        b.contains(widget.pageNumber),
                    builder: (context, pb) {
                      if (!pb.contains(widget.pageNumber)) {
                        return const SizedBox.shrink();
                      }
                      return MushafPageRibbon(
                        color: paperColors.accent,
                        onTap: () => _onRibbonTap(context),
                      );
                    },
                  ),
```

- [ ] **Step 3: Add the `_onRibbonTap` handler** (inside `_MushafPageViewState`)

```dart
  void _onRibbonTap(BuildContext context) {
    final cubit = context.read<PageBookmarkCubit>();
    cubit.toggle(widget.pageNumber);
    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: Text(S.of(context).pageRemovedFromBookmarks),
        action: SnackBarAction(
          label: S.of(context).undo,
          onPressed: () => cubit.toggle(widget.pageNumber),
        ),
      ),
    );
  }
```

- [ ] **Step 4: Analyze**

Run: `fvm flutter analyze lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated/
git commit -m "feat(mushaf): show ribbon on saved pages (tap to remove + undo)

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 9: Repoint the browse-bar Save button to page bookmarks

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`

- [ ] **Step 1: Swap the Save wiring**

In `mushaf_page.dart` (Phase 1 left the browse bar saving the first ayah of the page via `BookmarkCubit`). Replace the imports `bookmarks/.../bookmark_cubit.dart` + `bookmark_state.dart` with the page-bookmark ones:
```dart
import '../../../../bookmarks/presentation/cubit/page_bookmark_cubit.dart';
import '../../../../bookmarks/presentation/cubit/page_bookmark_state.dart';
```
Then in the browse-bar `builder` (the part that wraps `MushafBrowseBar` in a `BlocBuilder<BookmarkCubit, BookmarkState>`), replace that inner block with:
```dart
                            child: BlocBuilder<PageBookmarkCubit, PageBookmarkState>(
                              buildWhen: (a, b) =>
                                  a.contains(state.currentPage) !=
                                  b.contains(state.currentPage),
                              builder: (context, pb) {
                                final isSaved = pb.contains(state.currentPage);
                                return MushafBrowseBar(
                                  isSaved: isSaved,
                                  onSettings: () =>
                                      ReadingSettingsSheet.show(context),
                                  onPlay: _onPlayPage,
                                  onToggleSave: () => context
                                      .read<PageBookmarkCubit>()
                                      .toggle(state.currentPage),
                                );
                              },
                            ),
```
Delete the now-unused `_savableAyah()` helper (added in Phase 1) and the `QuranPageService` import **only if** it is no longer referenced (it is still used by `_onPlayPage`, so keep it).

- [ ] **Step 2: Analyze**

Run: `fvm flutter analyze lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`
Expected: No issues (remove any now-unused `BookmarkCubit`/`AyahIdentifier`-for-save imports the analyzer flags; `AyahIdentifier` is still used by `_onPlayPage`).

- [ ] **Step 3: Run the mushaf presentation suite**

Run: `fvm flutter test test/features/surah/presentation`
Expected: PASS.

- [ ] **Step 4: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/mushaf_page.dart
git commit -m "feat(mushaf): browse-bar Save toggles the page bookmark

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 10: "Pages" section in the Bookmarks screen

**Files:**
- Modify: `lib/features/bookmarks/presentation/pages/bookmarks_page.dart`
- Modify: `lib/l10n/intl_en.arb`, `lib/l10n/intl_ar.arb`

- [ ] **Step 1: Add the l10n section key**

`intl_en.arb` — add `"bookmarks_pages_section": "Pages",`
`intl_ar.arb` — add `"bookmarks_pages_section": "الصفحات",`
Regenerate l10n.

- [ ] **Step 2: Render saved pages**

In `bookmarks_page.dart`, add imports:
```dart
import 'package:quran_app/core/helper%20functions/locale_helpers.dart' show LocaleX; // already imported as context.isArabic — keep existing import
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_state.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/page_description.dart';
```
> (The `context.isArabic` extension is already imported in this file via `locale_helpers.dart` — do not duplicate; the line above is illustrative. Add only the three page-bookmark imports.)

Wrap the existing content with a `BlocBuilder<PageBookmarkCubit, PageBookmarkState>`. The simplest change: inside the `BlocBuilder<HadithBookmarkCubit, ...>` builder, also read page bookmarks. Change the empty-check and the `ListView` to include a Pages section. Replace the `final hadiths = ...` line region and the empty check with:
```dart
                      final hadiths = hadithState.bookmarks.toList()
                        ..sort((a, b) => a.bookSlug != b.bookSlug
                            ? a.bookSlug.compareTo(b.bookSlug)
                            : a.hadithNumber.compareTo(b.hadithNumber));

                      final pages = context
                          .watch<PageBookmarkCubit>()
                          .state
                          .pages
                          .toList()
                        ..sort();

                      if (ayahs.isEmpty && hadiths.isEmpty && pages.isEmpty) {
                        return Center(
                          child: Text(
                            S.of(context).no_bookmarks_yet,
                            style: TextStyle(color: scheme.onSurfaceVariant),
                          ),
                        );
                      }
```
Then add a Pages section at the top of the `ListView` children (before the Quran ayahs section):
```dart
                          if (pages.isNotEmpty) ...[
                            AppSectionHeader(
                              label: S.of(context).bookmarks_pages_section,
                            ),
                            const SizedBox(height: 10),
                            for (final p in pages) ...[
                              _PageBookmarkTile(page: p),
                              const SizedBox(height: 10),
                            ],
                            const SizedBox(height: 4),
                          ],
```

- [ ] **Step 3: Add the `_PageBookmarkTile`** (after `_QuranBookmarkTile`)

```dart
class _PageBookmarkTile extends StatelessWidget {
  const _PageBookmarkTile({required this.page});
  final int page;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final desc = describePage(page, localeCode: context.isArabic ? 'ar' : 'en');
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 12,
      onTap: () => context.push(AppRouter.mushafPath, extra: page),
      child: Row(
        children: [
          HugeIcon(
            icon: HugeIcons.strokeRoundedBookmark02,
            color: scheme.secondary,
            size: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  desc,
                  style: TS.bold16.copyWith(fontSize: 14, color: scheme.onSurface),
                ),
                const SizedBox(height: 2),
                Text(
                  '${S.of(context).pageByPage} ${page.toLocalized(context)}',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          HugeIcon(
            icon: HugeIcons.strokeRoundedArrowRight01,
            color: scheme.onSurfaceVariant,
            size: 16,
          ),
        ],
      ),
    );
  }
}
```
> `HugeIcons.strokeRoundedBookmark02` — if that exact name isn't in the installed `hugeicons` version, use `HugeIcons.strokeRoundedBookmark01` (already used in this file).

- [ ] **Step 4: Analyze + run**

Run: `fvm flutter analyze lib/features/bookmarks/presentation/pages/bookmarks_page.dart`
Expected: No issues.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/presentation/pages/bookmarks_page.dart lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated/
git commit -m "feat(bookmarks): Pages section listing saved pages with descriptions

Co-Authored-By: Claude Opus 4.8 <noreply@anthropic.com>"
```

---

### Task 11: Phase 3 verification

- [ ] **Step 1: Scoped test sweep**

Run:
```bash
fvm flutter test test/features/bookmarks test/features/surah/presentation
```
Expected: All PASS.

- [ ] **Step 2: Analyze**

Run: `fvm flutter analyze lib/features/bookmarks lib/features/surah/presentation/pages/mushaf`
Expected: No issues.

- [ ] **Step 3: Build (DI/Hive wiring at runtime)**

Run: `fvm flutter build apk --debug`
Expected: BUILD SUCCESSFUL.

- [ ] **Step 4: Manual gate (document in PR)**

1. On a page, tap **Save** in the browse bar → a **ribbon** appears at the top-trailing corner; the Save icon fills.
2. Scroll mode → ribbons appear on every saved page.
3. Tap a ribbon → it’s removed with a **snackbar Undo**; Undo restores it.
4. Bookmarks screen shows a **Pages** section with the surah/ayah description; tapping a row opens that page.
5. Ayah bookmarks (via the long-press popover) and their Bookmarks list section are **unchanged**.

---

## Self-review notes (author)

- **Spec coverage:** A6 page bookmarks → Tasks 1–5 (data/domain/cubit/DI); description → Task 6; ribbon → Tasks 7,8; Save repoint → Task 9; Bookmarks "Pages" section → Task 10. Ayah bookmarks untouched (verified — only `mushaf_page.dart` browse-bar Save changes, `ayah_action_popover` is not modified).
- **Placeholder scan:** none. Two "adjust if the package/icon name differs" notes (Task 6 surah spelling, Task 10 HugeIcon) are real environment checks with the exact fallback specified — not placeholders.
- **Type consistency:** `PageBookmarkState.contains(int)`, `PageBookmarkCubit.toggle(int)`, `describePage(int, {required String localeCode})`, `MushafPageRibbon({color, onTap})`, box name `page_bookmarks`, key `all` — consistent across data/cubit/UI/tests.
- **Test caveat honored:** all `flutter test` runs scoped under `test/features/...`.
- **Cross-phase dep:** Task 9 edits the browse-bar Save introduced in Phase 1; run Phase 1 first.
