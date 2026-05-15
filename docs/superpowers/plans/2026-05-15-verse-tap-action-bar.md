# Verse-tap Action Bar Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Tap a verse → highlight inline + slide-up action bar (Tafsir / Translation / Play / Bookmark / Share). Bar dismisses on tap-elsewhere. Play starts audio and the page view auto-swaps to follow recitation across page boundaries.

**Architecture:** State already lives in `MushafCubit` (`highlightedAyah`, `playingAyah`). We're (a) rebinding gestures, (b) adding a scaffold-level slide-up `AyahActionBar` widget driven by `highlightedAyah`, (c) adding a `BlocListener` on `playingAyah` to drive `PageController.animateToPage`, and (d) introducing a new `bookmarks` feature slice (Clean Arch) with Hive persistence.

**Tech Stack:** Flutter, flutter_bloc (Cubit), GetIt, Hive (offline persistence), share_plus (new dep), `package:quran` (verse text + ayah→page lookup via `QuranPageService`), dartz `Either<Failure, T>`, flutter_intl (l10n).

**Spec:** `docs/superpowers/specs/2026-05-15-verse-tap-action-bar-design.md`

---

## File Structure

**New files (bookmarks feature slice):**

- `lib/features/bookmarks/domain/repositories/bookmark_repository.dart` — abstract repo: `getAll()`, `toggle(ayah)`, `isBookmarked(ayah)`.
- `lib/features/bookmarks/domain/usecases/get_bookmarks.dart` — `Either<Failure, Set<AyahIdentifier>>`.
- `lib/features/bookmarks/domain/usecases/toggle_bookmark.dart` — `Either<Failure, bool>` (true = now bookmarked).
- `lib/features/bookmarks/data/datasources/local/bookmark_local_data_source.dart` — Hive box `'ayah_bookmarks'`, single key `'all'` storing `List<String>` of `'{surah}:{ayah}'`.
- `lib/features/bookmarks/data/repositories/bookmark_repository_impl.dart` — wraps data source, maps `CacheException → CacheFailure`.
- `lib/features/bookmarks/presentation/cubit/bookmark_cubit.dart` — app-level singleton; loads on construct, exposes `toggle()`.
- `lib/features/bookmarks/presentation/cubit/bookmark_state.dart` — `{ bookmarks: Set<AyahIdentifier>, loaded: bool, error: String? }`.
- `lib/features/bookmarks/bookmarks_di.dart` — `initBookmarks()`.

**New files (mushaf UI):**

- `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar.dart` — slide-up bar, 5 buttons.
- `lib/features/surah/presentation/pages/mushaf/auto_swap_helper.dart` — pure function computing the target PageView index for auto-swap on playback.

**Modified files:**

- `pubspec.yaml` — add `share_plus: ^11.0.0`.
- `lib/config/hive_config.dart` — open the new box.
- `lib/core/di/dependency_injection.dart` — call `initBookmarks()`.
- `lib/main.dart` — `BlocProvider(create: (_) => sl<BookmarkCubit>())` in the root `MultiBlocProvider`.
- `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart` — add `clearHighlight()`.
- `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart` — wrap with `BlocListener` for auto-swap; insert `AyahActionBar` between PageView and footer.
- `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart` — remove long-press; tap-empty calls `clearHighlight`.
- `lib/l10n/intl_en.arb`, `lib/l10n/intl_ar.arb` — new strings.

**Deleted files:**

- `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_sheet.dart`.

**Test files (mirror of source tree):**

- `test/features/bookmarks/domain/usecases/get_bookmarks_test.dart`
- `test/features/bookmarks/domain/usecases/toggle_bookmark_test.dart`
- `test/features/bookmarks/data/datasources/local/bookmark_local_data_source_test.dart`
- `test/features/bookmarks/data/repositories/bookmark_repository_impl_test.dart`
- `test/features/bookmarks/presentation/cubit/bookmark_cubit_test.dart`
- `test/features/surah/presentation/cubit/mushaf/mushaf_cubit_clear_highlight_test.dart` (extends the existing mushaf cubit tests)
- `test/features/surah/presentation/pages/mushaf/widgets/ayah_highlight_painter_merge_test.dart`
- `test/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar_test.dart`
- `test/features/surah/presentation/pages/mushaf/auto_swap_helper_test.dart`

---

### Task 1: Add `share_plus` dep and reserve the Hive bookmark box

**Files:**
- Modify: `pubspec.yaml`
- Modify: `lib/config/hive_config.dart`

- [ ] **Step 1: Add dependency**

Edit `pubspec.yaml` — under `dependencies:`, after the `quran:` block:

```yaml
  share_plus: ^11.0.0
```

- [ ] **Step 2: Open the Hive box on app start**

Edit `lib/config/hive_config.dart`. Final file content:

```dart
import 'package:hive_flutter/adapters.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';
import 'package:quran_app/features/home/data/models/location_hive_model.dart';
import 'package:quran_app/features/home/data/models/prayer_times_hive_model.dart';

Future<void> initHive() async {
  await Hive.initFlutter();

  Hive.registerAdapter(PrayerTimesHiveModelAdapter());
  await Hive.openBox<PrayerTimesHiveModel>('prayerTimesCache');

  await Hive.openBox<String>('ayahAudioCache');
  Hive.registerAdapter(LocationHiveModelAdapter());
  await Hive.openBox<LocationHiveModel>('userLocationCache');
  Hive.registerAdapter(HadithHiveModelAdapter());
  await Hive.openBox<HadithHiveModel>('ahadithCache');

  await Hive.openBox<List>('ayah_bookmarks');
}
```

- [ ] **Step 3: Resolve dependencies**

Run: `flutter pub get`
Expected: success, share_plus resolved.

- [ ] **Step 4: Commit**

```bash
git add pubspec.yaml pubspec.lock lib/config/hive_config.dart
git commit -m "chore(bookmarks): add share_plus and open ayah_bookmarks Hive box"
```

---

### Task 2: Bookmarks domain — repository contract

**Files:**
- Create: `lib/features/bookmarks/domain/repositories/bookmark_repository.dart`

- [ ] **Step 1: Create the abstract repository**

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';

abstract class BookmarkRepository {
  Future<Either<Failure, Set<AyahIdentifier>>> getAll();
  Future<Either<Failure, bool>> toggle(AyahIdentifier ayah);
  Future<Either<Failure, bool>> isBookmarked(AyahIdentifier ayah);
}
```

- [ ] **Step 2: Commit**

```bash
git add lib/features/bookmarks/domain/repositories/bookmark_repository.dart
git commit -m "feat(bookmarks): add BookmarkRepository contract"
```

---

### Task 3: Bookmarks domain — `GetBookmarks` use case (TDD)

**Files:**
- Test: `test/features/bookmarks/domain/usecases/get_bookmarks_test.dart`
- Create: `lib/features/bookmarks/domain/usecases/get_bookmarks.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/get_bookmarks.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

class _MockRepo extends Mock implements BookmarkRepository {}

void main() {
  late _MockRepo repo;
  late GetBookmarks usecase;

  setUp(() {
    repo = _MockRepo();
    usecase = GetBookmarks(repo);
  });

  test('delegates to repository.getAll', () async {
    final set = {const AyahIdentifier(surah: 1, ayah: 1)};
    when(() => repo.getAll()).thenAnswer((_) async => Right(set));

    final result = await usecase();

    expect(result, Right<Failure, Set<AyahIdentifier>>(set));
    verify(() => repo.getAll()).called(1);
  });

  test('propagates failure', () async {
    when(() => repo.getAll())
        .thenAnswer((_) async => const Left(CacheFailure('boom')));

    final result = await usecase();

    expect(result.isLeft(), isTrue);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/features/bookmarks/domain/usecases/get_bookmarks_test.dart`
Expected: FAIL — `get_bookmarks.dart` doesn't exist.

- [ ] **Step 3: Implement the use case**

Create `lib/features/bookmarks/domain/usecases/get_bookmarks.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../repositories/bookmark_repository.dart';

class GetBookmarks {
  GetBookmarks(this.repository);
  final BookmarkRepository repository;

  Future<Either<Failure, Set<AyahIdentifier>>> call() => repository.getAll();
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/features/bookmarks/domain/usecases/get_bookmarks_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/domain/usecases/get_bookmarks.dart test/features/bookmarks/domain/usecases/get_bookmarks_test.dart
git commit -m "feat(bookmarks): add GetBookmarks use case"
```

---

### Task 4: Bookmarks domain — `ToggleBookmark` use case (TDD)

**Files:**
- Test: `test/features/bookmarks/domain/usecases/toggle_bookmark_test.dart`
- Create: `lib/features/bookmarks/domain/usecases/toggle_bookmark.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/domain/repositories/bookmark_repository.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/toggle_bookmark.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

class _MockRepo extends Mock implements BookmarkRepository {}

void main() {
  late _MockRepo repo;
  late ToggleBookmark usecase;

  const ayah = AyahIdentifier(surah: 2, ayah: 255);

  setUpAll(() {
    registerFallbackValue(ayah);
  });

  setUp(() {
    repo = _MockRepo();
    usecase = ToggleBookmark(repo);
  });

  test('delegates to repository.toggle and returns new state', () async {
    when(() => repo.toggle(any())).thenAnswer((_) async => const Right(true));

    final result = await usecase(ayah);

    expect(result, const Right<Failure, bool>(true));
    verify(() => repo.toggle(ayah)).called(1);
  });

  test('propagates failure', () async {
    when(() => repo.toggle(any()))
        .thenAnswer((_) async => const Left(CacheFailure('boom')));

    final result = await usecase(ayah);

    expect(result.isLeft(), isTrue);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/features/bookmarks/domain/usecases/toggle_bookmark_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the use case**

Create `lib/features/bookmarks/domain/usecases/toggle_bookmark.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../repositories/bookmark_repository.dart';

class ToggleBookmark {
  ToggleBookmark(this.repository);
  final BookmarkRepository repository;

  Future<Either<Failure, bool>> call(AyahIdentifier ayah) =>
      repository.toggle(ayah);
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/features/bookmarks/domain/usecases/toggle_bookmark_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/domain/usecases/toggle_bookmark.dart test/features/bookmarks/domain/usecases/toggle_bookmark_test.dart
git commit -m "feat(bookmarks): add ToggleBookmark use case"
```

---

### Task 5: Bookmarks data — `BookmarkLocalDataSource` (TDD)

**Files:**
- Test: `test/features/bookmarks/data/datasources/local/bookmark_local_data_source_test.dart`
- Create: `lib/features/bookmarks/data/datasources/local/bookmark_local_data_source.dart`

The data source uses an injected `Box<List>` so tests can pass a mock box. Storage shape: a single key `'all'` holding a `List<String>` of `'{surah}:{ayah}'`.

- [ ] **Step 1: Write the failing test**

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/bookmarks/data/datasources/local/bookmark_local_data_source.dart';

class _MockBox extends Mock implements Box<List> {}

void main() {
  late _MockBox box;
  late BookmarkLocalDataSource ds;

  setUp(() {
    box = _MockBox();
    ds = BookmarkLocalDataSource(box: box);
  });

  group('getAll', () {
    test('returns empty set when no entries stored', () {
      when(() => box.get('all')).thenReturn(null);

      final result = ds.getAll();

      expect(result, isEmpty);
    });

    test('parses stored entries into AyahIdentifier set', () {
      when(() => box.get('all')).thenReturn(['1:1', '2:255']);

      final result = ds.getAll();

      expect(result.length, 2);
      expect(result.any((a) => a.surah == 1 && a.ayah == 1), isTrue);
      expect(result.any((a) => a.surah == 2 && a.ayah == 255), isTrue);
    });

    test('skips malformed entries', () {
      when(() => box.get('all')).thenReturn(['1:1', 'garbage', '2:abc']);

      final result = ds.getAll();

      expect(result.length, 1);
    });
  });

  group('toggle', () {
    test('adds when absent, returns true', () async {
      when(() => box.get('all')).thenReturn(<String>[]);
      when(() => box.put('all', any<List<String>>()))
          .thenAnswer((_) async {});

      final added = await ds.toggle(surah: 2, ayah: 255);

      expect(added, isTrue);
      verify(() => box.put('all', ['2:255'])).called(1);
    });

    test('removes when present, returns false', () async {
      when(() => box.get('all')).thenReturn(['2:255', '1:1']);
      when(() => box.put('all', any<List<String>>()))
          .thenAnswer((_) async {});

      final added = await ds.toggle(surah: 2, ayah: 255);

      expect(added, isFalse);
      final captured =
          verify(() => box.put('all', captureAny<List<String>>())).captured;
      expect(captured.single, ['1:1']);
    });
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/features/bookmarks/data/datasources/local/bookmark_local_data_source_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the data source**

Create `lib/features/bookmarks/data/datasources/local/bookmark_local_data_source.dart`:

```dart
import 'package:hive/hive.dart';

import '../../../../../core/errors/exceptions.dart';
import '../../../../quran_playback/domain/entities/ayah_identifier.dart';

class BookmarkLocalDataSource {
  BookmarkLocalDataSource({required this.box});
  final Box<List> box;

  static const _key = 'all';

  Set<AyahIdentifier> getAll() {
    final raw = box.get(_key);
    if (raw == null) return <AyahIdentifier>{};
    final result = <AyahIdentifier>{};
    for (final entry in raw) {
      final parsed = _parse(entry);
      if (parsed != null) result.add(parsed);
    }
    return result;
  }

  Future<bool> toggle({required int surah, required int ayah}) async {
    try {
      final current =
          (box.get(_key) ?? <String>[]).cast<String>().toList(growable: true);
      final key = '$surah:$ayah';
      final wasPresent = current.remove(key);
      if (!wasPresent) current.add(key);
      await box.put(_key, current);
      return !wasPresent;
    } catch (e) {
      throw CacheException('bookmark toggle failed: $e');
    }
  }

  AyahIdentifier? _parse(dynamic raw) {
    if (raw is! String) return null;
    final parts = raw.split(':');
    if (parts.length != 2) return null;
    final surah = int.tryParse(parts[0]);
    final ayah = int.tryParse(parts[1]);
    if (surah == null || ayah == null) return null;
    return AyahIdentifier(surah: surah, ayah: ayah);
  }
}
```

- [ ] **Step 4: Add `CacheException` to `core/errors/exceptions.dart`**

The existing file only has `LocationException` types. Edit `lib/core/errors/exceptions.dart` and append:

```dart

class CacheException implements Exception {
  CacheException(this.message);
  final String message;
  @override
  String toString() => 'CacheException: $message';
}
```

- [ ] **Step 5: Run the test and confirm it passes**

Run: `flutter test test/features/bookmarks/data/datasources/local/bookmark_local_data_source_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/bookmarks/data/datasources/local/bookmark_local_data_source.dart lib/core/errors/exceptions.dart test/features/bookmarks/data/datasources/local/bookmark_local_data_source_test.dart
git commit -m "feat(bookmarks): add BookmarkLocalDataSource"
```

---

### Task 6: Bookmarks data — `BookmarkRepositoryImpl` (TDD)

**Files:**
- Test: `test/features/bookmarks/data/repositories/bookmark_repository_impl_test.dart`
- Create: `lib/features/bookmarks/data/repositories/bookmark_repository_impl.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/exceptions.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/data/datasources/local/bookmark_local_data_source.dart';
import 'package:quran_app/features/bookmarks/data/repositories/bookmark_repository_impl.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

class _MockDS extends Mock implements BookmarkLocalDataSource {}

void main() {
  late _MockDS ds;
  late BookmarkRepositoryImpl repo;
  const ayah = AyahIdentifier(surah: 2, ayah: 255);

  setUpAll(() {
    registerFallbackValue(ayah);
  });

  setUp(() {
    ds = _MockDS();
    repo = BookmarkRepositoryImpl(dataSource: ds);
  });

  group('getAll', () {
    test('wraps data source result in Right', () async {
      when(() => ds.getAll()).thenReturn({ayah});

      final result = await repo.getAll();

      expect(result, Right<Failure, Set<AyahIdentifier>>({ayah}));
    });

    test('maps thrown exception to Left(CacheFailure)', () async {
      when(() => ds.getAll()).thenThrow(CacheException('boom'));

      final result = await repo.getAll();

      expect(result.isLeft(), isTrue);
      result.fold((f) => expect(f, isA<CacheFailure>()), (_) => fail('not Right'));
    });
  });

  group('toggle', () {
    test('returns Right(true) when newly added', () async {
      when(() => ds.toggle(surah: ayah.surah, ayah: ayah.ayah))
          .thenAnswer((_) async => true);

      final result = await repo.toggle(ayah);

      expect(result, const Right<Failure, bool>(true));
    });

    test('maps exception to Left(CacheFailure)', () async {
      when(() => ds.toggle(surah: ayah.surah, ayah: ayah.ayah))
          .thenThrow(CacheException('boom'));

      final result = await repo.toggle(ayah);

      expect(result.isLeft(), isTrue);
    });
  });

  group('isBookmarked', () {
    test('returns membership of the cached set', () async {
      when(() => ds.getAll()).thenReturn({ayah});

      final yes = await repo.isBookmarked(ayah);
      final no = await repo.isBookmarked(const AyahIdentifier(surah: 1, ayah: 1));

      expect(yes, const Right<Failure, bool>(true));
      expect(no, const Right<Failure, bool>(false));
    });
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/features/bookmarks/data/repositories/bookmark_repository_impl_test.dart`
Expected: FAIL.

- [ ] **Step 3: Implement the repository**

Create `lib/features/bookmarks/data/repositories/bookmark_repository_impl.dart`:

```dart
import 'package:dartz/dartz.dart';

import '../../../../core/errors/exceptions.dart';
import '../../../../core/errors/failure.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../domain/repositories/bookmark_repository.dart';
import '../datasources/local/bookmark_local_data_source.dart';

class BookmarkRepositoryImpl implements BookmarkRepository {
  BookmarkRepositoryImpl({required this.dataSource});
  final BookmarkLocalDataSource dataSource;

  @override
  Future<Either<Failure, Set<AyahIdentifier>>> getAll() async {
    try {
      return Right(dataSource.getAll());
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> toggle(AyahIdentifier ayah) async {
    try {
      final added =
          await dataSource.toggle(surah: ayah.surah, ayah: ayah.ayah);
      return Right(added);
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }

  @override
  Future<Either<Failure, bool>> isBookmarked(AyahIdentifier ayah) async {
    try {
      return Right(dataSource.getAll().contains(ayah));
    } on CacheException catch (e) {
      return Left(CacheFailure(e.message));
    }
  }
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/features/bookmarks/data/repositories/bookmark_repository_impl_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/data/repositories/bookmark_repository_impl.dart test/features/bookmarks/data/repositories/bookmark_repository_impl_test.dart
git commit -m "feat(bookmarks): add BookmarkRepositoryImpl"
```

---

### Task 7: Bookmarks presentation — `BookmarkCubit` + state (TDD)

**Files:**
- Create: `lib/features/bookmarks/presentation/cubit/bookmark_state.dart`
- Test: `test/features/bookmarks/presentation/cubit/bookmark_cubit_test.dart`
- Create: `lib/features/bookmarks/presentation/cubit/bookmark_cubit.dart`

- [ ] **Step 1: Create the state class**

```dart
import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';

class BookmarkState extends Equatable {
  final Set<AyahIdentifier> bookmarks;
  final bool loaded;
  final String? error;

  const BookmarkState({
    this.bookmarks = const {},
    this.loaded = false,
    this.error,
  });

  BookmarkState copyWith({
    Set<AyahIdentifier>? bookmarks,
    bool? loaded,
    Object? error = _sentinel,
  }) {
    return BookmarkState(
      bookmarks: bookmarks ?? this.bookmarks,
      loaded: loaded ?? this.loaded,
      error: identical(error, _sentinel) ? this.error : error as String?,
    );
  }

  bool contains(AyahIdentifier ayah) => bookmarks.contains(ayah);

  @override
  List<Object?> get props => [bookmarks, loaded, error];
}

const Object _sentinel = Object();
```

- [ ] **Step 2: Write the failing cubit test**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/get_bookmarks.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/toggle_bookmark.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

class _MockGet extends Mock implements GetBookmarks {}
class _MockToggle extends Mock implements ToggleBookmark {}

void main() {
  late _MockGet get;
  late _MockToggle toggle;

  const a1 = AyahIdentifier(surah: 1, ayah: 1);
  const a2 = AyahIdentifier(surah: 2, ayah: 255);

  setUpAll(() {
    registerFallbackValue(a1);
  });

  setUp(() {
    get = _MockGet();
    toggle = _MockToggle();
  });

  blocTest<BookmarkCubit, BookmarkState>(
    'loads bookmarks on construction',
    build: () {
      when(() => get()).thenAnswer((_) async => Right({a1, a2}));
      return BookmarkCubit(getBookmarks: get, toggleBookmark: toggle);
    },
    expect: () => [
      const BookmarkState(loaded: true, bookmarks: {a1, a2}),
    ],
  );

  blocTest<BookmarkCubit, BookmarkState>(
    'load failure emits error state',
    build: () {
      when(() => get()).thenAnswer(
          (_) async => const Left(CacheFailure('boom')));
      return BookmarkCubit(getBookmarks: get, toggleBookmark: toggle);
    },
    expect: () => [
      const BookmarkState(loaded: true, error: 'boom'),
    ],
  );

  blocTest<BookmarkCubit, BookmarkState>(
    'toggle adds ayah and updates state',
    setUp: () {
      when(() => get()).thenAnswer((_) async => const Right(<AyahIdentifier>{}));
      when(() => toggle(any())).thenAnswer((_) async => const Right(true));
    },
    build: () => BookmarkCubit(getBookmarks: get, toggleBookmark: toggle),
    act: (c) async {
      await Future<void>.delayed(Duration.zero);
      await c.toggle(a1);
    },
    expect: () => [
      const BookmarkState(loaded: true),
      const BookmarkState(loaded: true, bookmarks: {a1}),
    ],
  );

  blocTest<BookmarkCubit, BookmarkState>(
    'toggle removes ayah when already present',
    setUp: () {
      when(() => get()).thenAnswer((_) async => Right({a1}));
      when(() => toggle(any())).thenAnswer((_) async => const Right(false));
    },
    build: () => BookmarkCubit(getBookmarks: get, toggleBookmark: toggle),
    act: (c) async {
      await Future<void>.delayed(Duration.zero);
      await c.toggle(a1);
    },
    expect: () => [
      const BookmarkState(loaded: true, bookmarks: {a1}),
      const BookmarkState(loaded: true, bookmarks: <AyahIdentifier>{}),
    ],
  );

  blocTest<BookmarkCubit, BookmarkState>(
    'toggle failure sets error and leaves bookmarks unchanged',
    setUp: () {
      when(() => get()).thenAnswer((_) async => const Right(<AyahIdentifier>{}));
      when(() => toggle(any())).thenAnswer(
          (_) async => const Left(CacheFailure('save failed')));
    },
    build: () => BookmarkCubit(getBookmarks: get, toggleBookmark: toggle),
    act: (c) async {
      await Future<void>.delayed(Duration.zero);
      await c.toggle(a1);
    },
    expect: () => [
      const BookmarkState(loaded: true),
      const BookmarkState(loaded: true, error: 'save failed'),
    ],
  );
}
```

- [ ] **Step 3: Run the test and confirm it fails**

Run: `flutter test test/features/bookmarks/presentation/cubit/bookmark_cubit_test.dart`
Expected: FAIL.

- [ ] **Step 4: Implement the cubit**

Create `lib/features/bookmarks/presentation/cubit/bookmark_cubit.dart`:

```dart
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../domain/usecases/get_bookmarks.dart';
import '../../domain/usecases/toggle_bookmark.dart';
import 'bookmark_state.dart';

class BookmarkCubit extends Cubit<BookmarkState> {
  BookmarkCubit({
    required this.getBookmarks,
    required this.toggleBookmark,
  }) : super(const BookmarkState()) {
    _load();
  }

  final GetBookmarks getBookmarks;
  final ToggleBookmark toggleBookmark;

  Future<void> _load() async {
    final result = await getBookmarks();
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(loaded: true, error: failure.message)),
      (set) => emit(state.copyWith(loaded: true, bookmarks: set, error: null)),
    );
  }

  Future<void> toggle(AyahIdentifier ayah) async {
    if (!state.loaded) return;
    final result = await toggleBookmark(ayah);
    if (isClosed) return;
    result.fold(
      (failure) => emit(state.copyWith(error: failure.message)),
      (nowBookmarked) {
        final next = Set<AyahIdentifier>.from(state.bookmarks);
        if (nowBookmarked) {
          next.add(ayah);
        } else {
          next.remove(ayah);
        }
        emit(state.copyWith(bookmarks: next, error: null));
      },
    );
  }
}
```

- [ ] **Step 5: Run the test and confirm it passes**

Run: `flutter test test/features/bookmarks/presentation/cubit/bookmark_cubit_test.dart`
Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add lib/features/bookmarks/presentation/cubit/ test/features/bookmarks/presentation/cubit/
git commit -m "feat(bookmarks): add BookmarkCubit + state"
```

---

### Task 8: Bookmarks DI registration + app-root provider

**Files:**
- Create: `lib/features/bookmarks/bookmarks_di.dart`
- Modify: `lib/core/di/dependency_injection.dart`
- Modify: `lib/main.dart`

- [ ] **Step 1: Create the DI module**

```dart
import 'package:hive/hive.dart';

import '../../core/di/dependency_injection.dart';
import 'data/datasources/local/bookmark_local_data_source.dart';
import 'data/repositories/bookmark_repository_impl.dart';
import 'domain/repositories/bookmark_repository.dart';
import 'domain/usecases/get_bookmarks.dart';
import 'domain/usecases/toggle_bookmark.dart';
import 'presentation/cubit/bookmark_cubit.dart';

void initBookmarks() {
  sl.registerLazySingleton<BookmarkLocalDataSource>(
    () => BookmarkLocalDataSource(box: Hive.box<List>('ayah_bookmarks')),
  );
  sl.registerLazySingleton<BookmarkRepository>(
    () => BookmarkRepositoryImpl(dataSource: sl<BookmarkLocalDataSource>()),
  );
  sl.registerLazySingleton<GetBookmarks>(
    () => GetBookmarks(sl<BookmarkRepository>()),
  );
  sl.registerLazySingleton<ToggleBookmark>(
    () => ToggleBookmark(sl<BookmarkRepository>()),
  );
  sl.registerLazySingleton<BookmarkCubit>(
    () => BookmarkCubit(
      getBookmarks: sl<GetBookmarks>(),
      toggleBookmark: sl<ToggleBookmark>(),
    ),
  );
}
```

- [ ] **Step 2: Wire into the root DI**

Edit `lib/core/di/dependency_injection.dart`. Add the import and `initBookmarks()` call:

```dart
import 'package:dio/dio.dart';
import 'package:get_it/get_it.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app/features/ahadith/ahadith_di.dart';
import 'package:quran_app/features/bookmarks/bookmarks_di.dart';
import 'package:quran_app/features/home/home_di.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import '../../features/quran_playback/playback_di.dart';
import '../../features/surah/presentation/pages/mushaf/mushaf_di.dart';
import '../../features/surah/presentation/pages/surah_list/surah_list_di.dart';

final sl = GetIt.instance;

Future<void> initGetIt() async {
  sl.registerLazySingleton<AudioPlayer>(() => AudioPlayer());
  sl.registerLazySingleton<Dio>(() => Dio());
  sl.registerSingleton<SettingsCubit>(SettingsCubit());
  initHome();
  initSurahList();
  initMushaf();
  initAhadith();
  initPlayback();
  initBookmarks();
}
```

- [ ] **Step 3: Provide the cubit at app root**

Edit `lib/main.dart`. Update the `MultiBlocProvider`:

```dart
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_cubit.dart';

// ... inside runApp:
  runApp(
    MultiBlocProvider(
      providers: [
        BlocProvider(create: (_) => sl<SettingsCubit>()),
        BlocProvider(create: (_) => sl<BookmarkCubit>()),
      ],
      child: const QuranApp(),
    ),
  );
```

- [ ] **Step 4: Verify the app still builds**

Run: `flutter analyze`
Expected: no new errors.

Run: `flutter test test/features/bookmarks/`
Expected: all existing bookmark tests still pass.

- [ ] **Step 5: Commit**

```bash
git add lib/features/bookmarks/bookmarks_di.dart lib/core/di/dependency_injection.dart lib/main.dart
git commit -m "feat(bookmarks): register DI and provide cubit at app root"
```

---

### Task 9: `MushafCubit.clearHighlight()` (TDD)

**Files:**
- Test: `test/features/surah/presentation/cubit/mushaf/mushaf_cubit_clear_highlight_test.dart`
- Modify: `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`

- [ ] **Step 1: Write the failing test**

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';

class _FakeNotifier extends ValueNotifier<AyahIdentifier?> {
  _FakeNotifier() : super(null);
}

void main() {
  blocTest<MushafCubit, MushafState>(
    'clearHighlight clears highlightedAyah, leaves playingAyah intact',
    build: () => MushafCubit(initialPage: 1, currentAyahNotifier: _FakeNotifier())
      ..toggleHighlight(const AyahIdentifier(surah: 1, ayah: 1)),
    act: (c) => c.clearHighlight(),
    expect: () => [const MushafState(currentPage: 1)],
  );

  blocTest<MushafCubit, MushafState>(
    'clearHighlight emits nothing when already null',
    build: () => MushafCubit(initialPage: 1, currentAyahNotifier: _FakeNotifier()),
    act: (c) => c.clearHighlight(),
    expect: () => const <MushafState>[],
  );
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/features/surah/presentation/cubit/mushaf/mushaf_cubit_clear_highlight_test.dart`
Expected: FAIL — `clearHighlight` doesn't exist.

- [ ] **Step 3: Add the method**

Edit `lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart`. Insert immediately after the `toggleHighlight` method:

```dart
  void clearHighlight() {
    if (state.highlightedAyah == null) return;
    emit(state.copyWith(clearHighlighted: true));
  }
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/features/surah/presentation/cubit/mushaf/mushaf_cubit_clear_highlight_test.dart`
Also run the existing mushaf cubit tests to make sure nothing regressed:
Run: `flutter test test/features/surah/presentation/cubit/mushaf_image/mushaf_image_cubit_test.dart`
Expected: all PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart test/features/surah/presentation/cubit/mushaf/mushaf_cubit_clear_highlight_test.dart
git commit -m "feat(mushaf): add MushafCubit.clearHighlight"
```

---

### Task 10: Lock the highlight merged-shape rule (§3.4) with a test

The current `AyahHighlightPainter` already merges vertically-adjacent line-rects into one rounded path. The spec §3.4 makes this a hard contractual requirement that must be protected by tests.

**Approach:** A custom `Canvas` recorder counts `drawPath` and `drawRRect` calls when the painter runs against synthetic ayah bounds. We expect **exactly one** `drawPath` per connected group.

**Files:**
- Test: `test/features/surah/presentation/pages/mushaf/widgets/ayah_highlight_painter_merge_test.dart`

- [ ] **Step 1: Write the test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_highlight_painter.dart';

class _RecordingCanvas extends Mock implements Canvas {}

void main() {
  setUpAll(() {
    registerFallbackValue(Path());
    registerFallbackValue(Paint());
    registerFallbackValue(RRect.zero);
  });

  const ayah = AyahIdentifier(surah: 2, ayah: 255);
  const size = Size(100, 100);

  AyahBoundEntity boundWith(List<NormalizedRect> lines) =>
      AyahBoundEntity(ayah: ayah, lines: lines);

  AyahHighlightPainter buildPainter(List<AyahBoundEntity> ayahs) =>
      AyahHighlightPainter(
        ayahs: ayahs,
        highlightedAyah: ayah,
        prevHighlightedAyah: null,
        playingAyah: null,
        prevPlayingAyah: null,
        highlightColor: const Color(0xFF00FF00),
        playingColor: const Color(0xFFFF0000),
        animationValue: 1.0,
      );

  test('three vertically-adjacent line-rects render as ONE merged path', () {
    final canvas = _RecordingCanvas();
    when(() => canvas.drawPath(any(), any())).thenReturn(null);
    when(() => canvas.drawRRect(any(), any())).thenReturn(null);

    final painter = buildPainter([
      boundWith(const [
        NormalizedRect(x: 0.1, y: 0.10, w: 0.8, h: 0.05),
        NormalizedRect(x: 0.1, y: 0.15, w: 0.8, h: 0.05),
        NormalizedRect(x: 0.1, y: 0.20, w: 0.8, h: 0.05),
      ]),
    ]);

    painter.paint(canvas, size);

    verify(() => canvas.drawPath(any(), any())).called(1);
    verifyNever(() => canvas.drawRRect(any(), any()));
  });

  test('vertical gap between lines splits into TWO merged paths', () {
    final canvas = _RecordingCanvas();
    when(() => canvas.drawPath(any(), any())).thenReturn(null);

    final painter = buildPainter([
      boundWith(const [
        NormalizedRect(x: 0.1, y: 0.10, w: 0.8, h: 0.05),
        // Big vertical gap below (avgHeight*0.3 threshold is 0.015; gap is 0.25)
        NormalizedRect(x: 0.1, y: 0.40, w: 0.8, h: 0.05),
      ]),
    ]);

    painter.paint(canvas, size);

    verify(() => canvas.drawPath(any(), any())).called(2);
  });

  test('rule applies to playing-highlight as well as user-highlight', () {
    final canvas = _RecordingCanvas();
    when(() => canvas.drawPath(any(), any())).thenReturn(null);

    final painter = AyahHighlightPainter(
      ayahs: [
        boundWith(const [
          NormalizedRect(x: 0.1, y: 0.10, w: 0.8, h: 0.05),
          NormalizedRect(x: 0.1, y: 0.15, w: 0.8, h: 0.05),
        ]),
      ],
      highlightedAyah: null,
      prevHighlightedAyah: null,
      playingAyah: ayah,
      prevPlayingAyah: null,
      highlightColor: const Color(0xFF00FF00),
      playingColor: const Color(0xFFFF0000),
      animationValue: 1.0,
    );

    painter.paint(canvas, size);

    verify(() => canvas.drawPath(any(), any())).called(1);
  });
}
```

- [ ] **Step 2: Run the test**

Run: `flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_highlight_painter_merge_test.dart`
Expected: PASS (the painter already implements the rule; this test locks it).

- [ ] **Step 3: Commit**

```bash
git add test/features/surah/presentation/pages/mushaf/widgets/ayah_highlight_painter_merge_test.dart
git commit -m "test(mushaf): lock merged-shape highlight rule (§3.4)"
```

---

### Task 11: Localization strings

**Files:**
- Modify: `lib/l10n/intl_en.arb`
- Modify: `lib/l10n/intl_ar.arb`
- Regenerate: `lib/generated/l10n.dart` (auto by flutter_intl IDE extension on save, or via CLI)

- [ ] **Step 1: Add English strings**

Append to `lib/l10n/intl_en.arb` before the closing `}`:

```json
,
"tafsir": "Tafsir",
"translation": "Translation",
"play": "Play",
"bookmark": "Bookmark",
"share": "Share",
"coming_soon": "Coming soon",
"bookmark_added": "Bookmarked",
"bookmark_removed": "Bookmark removed",
"bookmark_save_failed": "Couldn't save bookmark",
"share_failed": "Couldn't open share sheet"
```

(If the file already has a trailing comma after the last existing key, drop the leading comma above.)

- [ ] **Step 2: Add Arabic strings**

Append to `lib/l10n/intl_ar.arb` before the closing `}`:

```json
,
"tafsir": "تفسير",
"translation": "ترجمة",
"play": "تشغيل",
"bookmark": "حفظ",
"share": "مشاركة",
"coming_soon": "قريبًا",
"bookmark_added": "تم الحفظ",
"bookmark_removed": "تم إزالة الحفظ",
"bookmark_save_failed": "تعذّر حفظ المرجعية",
"share_failed": "تعذّر فتح نافذة المشاركة"
```

- [ ] **Step 3: Regenerate localization**

If you have the flutter_intl IDE extension installed, save both files — generation happens automatically. Otherwise run:

```
dart run intl_utils:generate
```

Expected: `lib/generated/l10n.dart` updated with new getters (e.g., `String get tafsir`).

- [ ] **Step 4: Verify**

Run: `flutter analyze`
Expected: no errors. New getters exist on `S.of(context)`.

- [ ] **Step 5: Commit**

```bash
git add lib/l10n/intl_en.arb lib/l10n/intl_ar.arb lib/generated/l10n.dart
git commit -m "feat(l10n): add action-bar strings (en + ar)"
```

---

### Task 12: `AyahActionBar` widget (TDD)

**Files:**
- Test: `test/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar_test.dart`
- Create: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar.dart`

The bar is a stateless widget that reads `MushafCubit.highlightedAyah` to drive visibility (slide + opacity + IgnorePointer) and reads `BookmarkCubit` for the star icon state. Test harness uses fake cubits.

- [ ] **Step 1: Write the failing widget test**

```dart
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/bookmark_state.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar.dart';
import 'package:quran_app/generated/l10n.dart';

class _FakeMushafCubit extends Cubit<MushafState> implements MushafCubit {
  _FakeMushafCubit(super.initial);
  bool clearCalled = false;
  @override
  void clearHighlight() {
    clearCalled = true;
    emit(state.copyWith(clearHighlighted: true));
  }
  @override
  void toggleHighlight(_) {}
  @override
  void setPage(int page) {}
  @override
  ValueNotifier<AyahIdentifier?> get debugNotifier =>
      throw UnimplementedError();
}

class _FakeBookmarkCubit extends Cubit<BookmarkState> implements BookmarkCubit {
  _FakeBookmarkCubit(super.initial);
  AyahIdentifier? toggled;
  @override
  Future<void> toggle(AyahIdentifier ayah) async {
    toggled = ayah;
  }
  @override
  GetBookmarks get getBookmarks => throw UnimplementedError();
  @override
  ToggleBookmark get toggleBookmark => throw UnimplementedError();
}

class _MockPlayback extends Mock implements PlaybackCubit {}

const _ayah = AyahIdentifier(surah: 2, ayah: 255);

Widget _harness({
  required MushafState mushafState,
  required BookmarkState bookmarkState,
  required PlaybackCubit playback,
  _FakeMushafCubit? mushafCubit,
  _FakeBookmarkCubit? bookmarkCubit,
}) {
  return MaterialApp(
    localizationsDelegates: const [
      S.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
    ],
    supportedLocales: S.delegate.supportedLocales,
    home: Scaffold(
      body: MultiBlocProvider(
        providers: [
          BlocProvider<MushafCubit>.value(
              value: mushafCubit ?? _FakeMushafCubit(mushafState)),
          BlocProvider<BookmarkCubit>.value(
              value: bookmarkCubit ?? _FakeBookmarkCubit(bookmarkState)),
          BlocProvider<PlaybackCubit>.value(value: playback),
        ],
        child: const Align(
          alignment: Alignment.bottomCenter,
          child: AyahActionBar(),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(_ayah);
  });

  testWidgets('bar is offscreen and ignores pointers when no highlight',
      (tester) async {
    final playback = _MockPlayback();
    when(() => playback.state).thenReturn(const PlaybackState());
    when(() => playback.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_harness(
      mushafState: const MushafState(currentPage: 1),
      bookmarkState: const BookmarkState(loaded: true),
      playback: playback,
    ));
    await tester.pump();

    final ignorePointer = tester.widget<IgnorePointer>(find.byType(IgnorePointer));
    expect(ignorePointer.ignoring, isTrue);
  });

  testWidgets('bar is visible when a highlight is present', (tester) async {
    final playback = _MockPlayback();
    when(() => playback.state).thenReturn(const PlaybackState());
    when(() => playback.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_harness(
      mushafState: const MushafState(currentPage: 1, highlightedAyah: _ayah),
      bookmarkState: const BookmarkState(loaded: true),
      playback: playback,
    ));
    await tester.pumpAndSettle();

    final ignorePointer = tester.widget<IgnorePointer>(find.byType(IgnorePointer));
    expect(ignorePointer.ignoring, isFalse);
  });

  testWidgets('tapping Play calls PlaybackCubit.playFromAyah and clears highlight',
      (tester) async {
    final playback = _MockPlayback();
    when(() => playback.state).thenReturn(const PlaybackState());
    when(() => playback.stream).thenAnswer((_) => const Stream.empty());
    when(() => playback.playFromAyah(any())).thenAnswer((_) async {});

    final mushaf = _FakeMushafCubit(
        const MushafState(currentPage: 1, highlightedAyah: _ayah));

    await tester.pumpWidget(_harness(
      mushafState: const MushafState(currentPage: 1, highlightedAyah: _ayah),
      bookmarkState: const BookmarkState(loaded: true),
      playback: playback,
      mushafCubit: mushaf,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ayah_bar_play')));
    await tester.pumpAndSettle();

    verify(() => playback.playFromAyah(_ayah)).called(1);
    expect(mushaf.clearCalled, isTrue);
  });

  testWidgets('tapping Bookmark calls BookmarkCubit.toggle', (tester) async {
    final playback = _MockPlayback();
    when(() => playback.state).thenReturn(const PlaybackState());
    when(() => playback.stream).thenAnswer((_) => const Stream.empty());

    final bookmark = _FakeBookmarkCubit(const BookmarkState(loaded: true));

    await tester.pumpWidget(_harness(
      mushafState: const MushafState(currentPage: 1, highlightedAyah: _ayah),
      bookmarkState: const BookmarkState(loaded: true),
      playback: playback,
      bookmarkCubit: bookmark,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ayah_bar_bookmark')));
    await tester.pumpAndSettle();

    expect(bookmark.toggled, _ayah);
  });

  testWidgets('tapping Tafsir shows a snackbar', (tester) async {
    final playback = _MockPlayback();
    when(() => playback.state).thenReturn(const PlaybackState());
    when(() => playback.stream).thenAnswer((_) => const Stream.empty());

    await tester.pumpWidget(_harness(
      mushafState: const MushafState(currentPage: 1, highlightedAyah: _ayah),
      bookmarkState: const BookmarkState(loaded: true),
      playback: playback,
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const ValueKey('ayah_bar_tafsir')));
    await tester.pump();

    expect(find.byType(SnackBar), findsOneWidget);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar_test.dart`
Expected: FAIL — widget doesn't exist.

- [ ] **Step 3: Implement the widget**

Create `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar.dart`:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as quran;
import 'package:share_plus/share_plus.dart';

import '../../../../../bookmarks/presentation/cubit/bookmark_cubit.dart';
import '../../../../../bookmarks/presentation/cubit/bookmark_state.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../../../../generated/l10n.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';

class AyahActionBar extends StatelessWidget {
  const AyahActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MushafCubit, MushafState>(
      buildWhen: (a, b) => a.highlightedAyah != b.highlightedAyah,
      builder: (context, state) {
        final ayah = state.highlightedAyah;
        final visible = ayah != null;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 8, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _BarButton(
                          key: const ValueKey('ayah_bar_tafsir'),
                          icon: Icons.menu_book_outlined,
                          label: S.of(context).tafsir,
                          onTap: () => _comingSoon(context),
                        ),
                        _BarButton(
                          key: const ValueKey('ayah_bar_translation'),
                          icon: Icons.translate,
                          label: S.of(context).translation,
                          onTap: () => _comingSoon(context),
                        ),
                        _BarButton(
                          key: const ValueKey('ayah_bar_play'),
                          icon: Icons.play_arrow,
                          label: S.of(context).play,
                          prominent: true,
                          onTap: () => _onPlay(context, ayah),
                        ),
                        _BookmarkButton(ayah: ayah),
                        _BarButton(
                          key: const ValueKey('ayah_bar_share'),
                          icon: Icons.share,
                          label: S.of(context).share,
                          onTap: () => _onShare(context, ayah),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onPlay(BuildContext context, AyahIdentifier? ayah) {
    if (ayah == null) return;
    context.read<PlaybackCubit>().playFromAyah(ayah);
    context.read<MushafCubit>().clearHighlight();
  }

  Future<void> _onShare(BuildContext context, AyahIdentifier? ayah) async {
    if (ayah == null) return;
    try {
      final text = quran.getVerse(ayah.surah, ayah.ayah);
      await Share.share('$text — ${ayah.surah}:${ayah.ayah}');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).share_failed)),
      );
    }
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context).coming_soon)),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.prominent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = prominent ? scheme.primary : scheme.onSurface;
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.ayah});
  final AyahIdentifier? ayah;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookmarkCubit, BookmarkState>(
      buildWhen: (a, b) {
        if (ayah == null) return false;
        return a.contains(ayah!) != b.contains(ayah!);
      },
      builder: (context, state) {
        final on = ayah != null && state.contains(ayah!);
        return _BarButton(
          key: const ValueKey('ayah_bar_bookmark'),
          icon: on ? Icons.bookmark : Icons.bookmark_border,
          label: S.of(context).bookmark,
          onTap: () => _onTap(context),
        );
      },
    );
  }

  Future<void> _onTap(BuildContext context) async {
    final a = ayah;
    if (a == null) return;
    final cubit = context.read<BookmarkCubit>();
    final wasOn = cubit.state.contains(a);
    await cubit.toggle(a);
    if (!context.mounted) return;
    final state = cubit.state;
    final message = state.error != null
        ? S.of(context).bookmark_save_failed
        : (wasOn ? S.of(context).bookmark_removed : S.of(context).bookmark_added);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar_test.dart`
Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar.dart test/features/surah/presentation/pages/mushaf/widgets/ayah_action_bar_test.dart
git commit -m "feat(mushaf): add AyahActionBar widget"
```

---

### Task 13: Update `MushafPageView` gesture — remove long-press, handle empty-tap clear

**Files:**
- Modify: `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`

- [ ] **Step 1: Update the gesture handlers**

In `lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart`:

1. Remove the import of `AyahActionSheet` and the `PlaybackCubit` import if it's only used for long-press.
2. Replace the `GestureDetector` block with tap-only.
3. Update `_handleTap` to call `clearHighlight()` on null hits.
4. Delete the `_handleLongPress` method entirely.

Final relevant section of the file (the `GestureDetector` and handler methods):

```dart
                  if (entity != null)
                    Positioned.fill(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTapUp: (details) => _handleTap(
                          context,
                          details.localPosition,
                          constraints,
                          entity.ayahs,
                        ),
                      ),
                    ),
```

```dart
  void _handleTap(BuildContext context, Offset local, BoxConstraints c,
      List<AyahBoundEntity> ayahs) {
    final hit = _hitTest(local, c, ayahs);
    final cubit = context.read<MushafCubit>();
    if (hit != null) {
      cubit.toggleHighlight(hit);
    } else if (cubit.state.highlightedAyah != null) {
      cubit.clearHighlight();
    }
  }
```

Delete `_handleLongPress`. Also remove the unused `import 'ayah_action_sheet.dart';` and the `PlaybackCubit` import if no other code in the file references it.

- [ ] **Step 2: Verify**

Run: `flutter analyze`
Expected: no errors. If the analyzer complains about unused imports, remove them.

Run: `flutter test`
Expected: all tests still pass.

- [ ] **Step 3: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/widgets/mushaf_page_view.dart
git commit -m "refactor(mushaf): make tap the only ayah gesture; remove long-press modal"
```

---

### Task 14: Wire `AyahActionBar` and auto-swap into `MushafPage` (TDD)

**Files:**
- Create: `lib/features/surah/presentation/pages/mushaf/auto_swap_helper.dart`
- Test: `test/features/surah/presentation/pages/mushaf/auto_swap_helper_test.dart`
- Modify: `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`
- Modify: `lib/features/quran_playback/playback_di.dart`

The auto-swap behaviour has two parts: (a) a **pure function** that decides the target page index, and (b) a **`BlocListener`** in `MushafPage` that runs the function and calls `animateToPage`. We unit-test the pure function (no Flutter, no assets, no GetIt mocking gymnastics) and rely on the manual smoke test in Task 16 for the `BlocListener` glue.

- [ ] **Step 1: Write the failing pure-function test**

Create `test/features/surah/presentation/pages/mushaf/auto_swap_helper_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/auto_swap_helper.dart';

class _MockPageService extends Mock implements QuranPageService {}

void main() {
  late _MockPageService service;

  setUp(() => service = _MockPageService());

  test('returns target index when playingAyah is on a different page', () {
    when(() => service.getPageForAyah(2, 255)).thenReturn(5);

    final result = computeAutoSwapTargetIndex(
      playingAyah: const AyahIdentifier(surah: 2, ayah: 255),
      currentPageIndex: 0,
      pageService: service,
    );

    expect(result, 4); // page 5 → index 4
  });

  test('returns null when playingAyah is on the current page', () {
    when(() => service.getPageForAyah(1, 1)).thenReturn(1);

    final result = computeAutoSwapTargetIndex(
      playingAyah: const AyahIdentifier(surah: 1, ayah: 1),
      currentPageIndex: 0,
      pageService: service,
    );

    expect(result, isNull);
  });

  test('returns null when playingAyah is null', () {
    final result = computeAutoSwapTargetIndex(
      playingAyah: null,
      currentPageIndex: 0,
      pageService: service,
    );

    expect(result, isNull);
    verifyNever(() => service.getPageForAyah(any(), any()));
  });

  test('returns null when currentPageIndex is null (controller detached)', () {
    when(() => service.getPageForAyah(2, 255)).thenReturn(5);

    final result = computeAutoSwapTargetIndex(
      playingAyah: const AyahIdentifier(surah: 2, ayah: 255),
      currentPageIndex: null,
      pageService: service,
    );

    expect(result, isNull);
  });
}
```

- [ ] **Step 2: Run the test and confirm it fails**

Run: `flutter test test/features/surah/presentation/pages/mushaf/auto_swap_helper_test.dart`
Expected: FAIL — `auto_swap_helper.dart` doesn't exist.

- [ ] **Step 3: Implement the pure helper**

Create `lib/features/surah/presentation/pages/mushaf/auto_swap_helper.dart`:

```dart
import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../quran_playback/domain/services/quran_page_service.dart';

/// Returns the PageView index the controller should animate to in response
/// to a [playingAyah] change, or null if no swap is needed.
///
/// Returns null when:
/// - [playingAyah] is null (playback stopped),
/// - [currentPageIndex] is null (controller not yet attached),
/// - the playing ayah is already on the current page.
int? computeAutoSwapTargetIndex({
  required AyahIdentifier? playingAyah,
  required int? currentPageIndex,
  required QuranPageService pageService,
}) {
  if (playingAyah == null) return null;
  if (currentPageIndex == null) return null;
  final target = pageService.getPageForAyah(playingAyah.surah, playingAyah.ayah) - 1;
  if (target == currentPageIndex) return null;
  return target;
}
```

- [ ] **Step 4: Run the test and confirm it passes**

Run: `flutter test test/features/surah/presentation/pages/mushaf/auto_swap_helper_test.dart`
Expected: PASS.

- [ ] **Step 5: Adjust playback DI to register the abstract `QuranPageService` type**

The implementation reads `sl<QuranPageService>()`. The existing playback DI registers the concrete `QuranPageServiceImpl` type instead. Edit `lib/features/quran_playback/playback_di.dart`. Change the page-service registration line:

```dart
  sl.registerLazySingleton<QuranPageService>(() => QuranPageServiceImpl());
```

(Replace the existing `sl.registerLazySingleton<QuranPageServiceImpl>(...)` line.)

Update the `PlaybackCubit` registration to resolve the abstract:

```dart
  sl.registerLazySingleton<PlaybackCubit>(
    () => PlaybackCubit(
      ayahSequenceService: sl<AyahSequenceService>(),
      repository: sl<QuranPlaybackRepo>(),
      pageService: sl<QuranPageService>(),
    ),
  );
```

- [ ] **Step 6: Implement the page-level wiring**

Edit `lib/features/surah/presentation/pages/mushaf/mushaf_page.dart`. Final content:

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/dependency_injection.dart';
import '../../../../quran_playback/domain/services/quran_page_service.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';
import '../../cubit/mushaf/mushaf_state.dart';
import 'auto_swap_helper.dart';
import 'widgets/ayah_action_bar.dart';
import 'widgets/mushaf_page_number_text.dart';
import 'widgets/mushaf_page_view.dart';

class MushafPage extends StatefulWidget {
  const MushafPage({super.key, required this.initialPage});
  final int initialPage;

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  late final PageController _controller;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialPage - 1);
    _controller.addListener(_precacheNeighbours);
  }

  @override
  void dispose() {
    _controller.removeListener(_precacheNeighbours);
    _controller.dispose();
    super.dispose();
  }

  int _pageNumberFor(int index) => index + 1;

  void _precacheNeighbours() {
    final idx = _controller.page?.round();
    if (idx == null) return;
    for (final neighbour in [idx - 1, idx + 1]) {
      if (neighbour < 0 || neighbour > 603) continue;
      final page = _pageNumberFor(neighbour);
      precacheImage(
        AssetImage(
            'assets/mushaf/pages/page_${page.toString().padLeft(3, '0')}.png'),
        context,
      );
    }
  }

  void _onPlayingAyahChanged(MushafState state) {
    if (!_controller.hasClients) return;
    final targetIdx = computeAutoSwapTargetIndex(
      playingAyah: state.playingAyah,
      currentPageIndex: _controller.page?.round(),
      pageService: sl<QuranPageService>(),
    );
    if (targetIdx == null) return;
    _controller.animateToPage(
      targetIdx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MushafCubit, MushafState>(
      listenWhen: (a, b) => a.playingAyah != b.playingAyah,
      listener: (_, state) => _onPlayingAyahChanged(state),
      child: Scaffold(
        body: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: 604,
                    onPageChanged: (i) =>
                        context.read<MushafCubit>().setPage(_pageNumberFor(i)),
                    itemBuilder: (_, i) =>
                        MushafPageView(pageNumber: _pageNumberFor(i)),
                  ),
                ),
              ),
              const AyahActionBar(),
              BlocBuilder<MushafCubit, MushafState>(
                buildWhen: (a, b) => a.currentPage != b.currentPage,
                builder: (context, state) =>
                    MushafPageNumberText(pageNumber: state.currentPage),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
```

- [ ] **Step 7: Run the full test suite**

Run: `flutter test`
Expected: full suite PASSES.

Run: `flutter analyze`
Expected: no errors.

- [ ] **Step 8: Commit**

```bash
git add lib/features/surah/presentation/pages/mushaf/mushaf_page.dart lib/features/surah/presentation/pages/mushaf/auto_swap_helper.dart lib/features/quran_playback/playback_di.dart test/features/surah/presentation/pages/mushaf/auto_swap_helper_test.dart
git commit -m "feat(mushaf): wire AyahActionBar and auto-swap to playingAyah"
```

---

### Task 15: Delete the obsolete `AyahActionSheet`

**Files:**
- Delete: `lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_sheet.dart`

- [ ] **Step 1: Confirm no references remain**

Run a grep:

Use the Grep tool with pattern `AyahActionSheet` and confirm zero matches across `lib/` and `test/`. If anything remains, remove those imports/usages first.

- [ ] **Step 2: Delete the file**

```bash
git rm lib/features/surah/presentation/pages/mushaf/widgets/ayah_action_sheet.dart
```

- [ ] **Step 3: Verify**

Run: `flutter analyze`
Expected: no errors.

Run: `flutter test`
Expected: full suite PASSES.

- [ ] **Step 4: Commit**

```bash
git commit -m "chore(mushaf): remove obsolete modal AyahActionSheet"
```

---

### Task 16: Manual smoke test

**Goal:** verify the feature end-to-end on a real device/emulator. No code changes; this catches anything tests can't.

- [ ] **Step 1: Launch the app**

Run: `flutter run`
Navigate to the mushaf reader on any page.

- [ ] **Step 2: Walk the checklist**

- Tap an ayah → highlight appears, bar slides up under ~200ms.
- Tap a different ayah → highlight switches without flicker, bar stays.
- Tap the same ayah again → bar slides down, highlight clears.
- Tap a non-ayah area → bar slides down, highlight clears.
- Swipe to another page → bar dismisses automatically.
- Tap Tafsir → "Coming soon" snackbar.
- Tap Translation → "Coming soon" snackbar.
- Tap Bookmark → "Bookmarked" snackbar; star icon fills. Tap again → "Bookmark removed", star unfills. Kill and relaunch app → bookmark survives.
- Tap Share → native share sheet opens with verse text.
- Tap Play → bar dismisses, recitation begins on tapped ayah; highlight follows recitation.
- During playback, when an ayah on the next page becomes current, the page swipes to it automatically within ~300ms.
- Switch app locale to Arabic in settings → bar labels render in Arabic; RTL layout preserved.
- Verify highlight is a single all-rounded shape on multi-line ayahs (§3.4). Try Al-Baqarah 282 or a long verse spanning multiple lines.

- [ ] **Step 3: Document any defects**

If any flow fails, create a new follow-up task in the task list with the specific repro steps. Do not patch defects inside this plan — open a separate fix.

---

## Self-Review

**Spec coverage:**
- §1.1 highlight on tap → Task 13 (existing toggleHighlight kept).
- §1.2 slide-up bar with 5 actions → Tasks 11, 12.
- §1.3 tap-elsewhere dismiss → Task 13 (clearHighlight on null hit).
- §1.4 highlight persists, Play follows playback → Tasks 12, 14.
- §1.5 merged-shape rule → Task 10 (locks it with tests).
- §1.6 auto-swap → Task 14.
- §3 architecture (state in `MushafCubit`, new bookmarks slice) → Tasks 1-9.
- §3.3 deletions → Tasks 13, 15.
- §5 bookmarks slice → Tasks 2-8.
- §6 `AyahActionBar` widget composition → Task 12.
- §7 auto-swap method → Task 14.
- §8 localisation strings → Task 11.
- §9 error handling — Bookmark CacheFailure path → Task 7 covers state, Task 12 covers snackbar. Share try/catch → Task 12.
- §11 testing → Tasks 3, 4, 5, 6, 7, 9, 10, 12, 14 (every unit listed). The MushafPage auto-swap test (§11.6) is implemented as a unit test on the extracted pure helper `computeAutoSwapTargetIndex`, with the `BlocListener` glue covered by the smoke test in Task 16 — mounting the full `MushafPage` in widget tests is impractical because `MushafPageView.initState` reads `sl<GetMushafPage>()` against assets that aren't present in `flutter test`.
- §13 DoD → Task 16 walks all acceptance criteria.

**Placeholder scan:** no TBDs, no "implement later". Every code step has the actual code.

**Type consistency:**
- `BookmarkRepository.toggle(AyahIdentifier)` → consistent across Tasks 2, 4, 6, 7.
- `BookmarkLocalDataSource.toggle({surah, ayah})` → consistent in Tasks 5, 6.
- `MushafCubit.clearHighlight()` → introduced in Task 9, used in Tasks 12, 13.
- `QuranPageService.getPageForAyah(int, int)` → matches existing signature; Task 14 only changes the DI binding, not the method.
- l10n keys (`tafsir`, `translation`, `play`, `bookmark`, `share`, `coming_soon`, `bookmark_added`, `bookmark_removed`, `bookmark_save_failed`, `share_failed`) → defined in Task 11, used in Task 12.

Plan is internally consistent.
