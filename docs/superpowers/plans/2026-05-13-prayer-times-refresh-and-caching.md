# Prayer Times: After-Isha Refresh & Monthly Caching — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Eliminate the loading-state flash on after-Isha auto-refresh, add a midnight auto-refresh trigger, and replace the broken/dead monthly-caching pipeline with a working `PreCachePrayerTimes` use case fired on every successful context load.

**Architecture:** Clean Architecture (domain / data / presentation). Strict layer boundaries per `.claude/rules/architecture.md`. `dartz.Either<Failure, T>` for all repo/use-case returns. `GetIt` (`sl`) for DI. `flutter_bloc` Cubits for state. `Hive` for offline cache.

**Tech Stack:** Dart / Flutter, `flutter_bloc`, `dartz`, `equatable`, `hive`/`hive_flutter`, `dio`, `intl`, `flutter_animate`, `get_it`. Tests use `mocktail` and `bloc_test` (added in Task 0).

---

## File Map

### NEW files
- `test/features/home/data/datasources/local/prayer_times_local_data_source_test.dart`
- `test/features/home/data/datasources/remote/prayer_time_remote_data_source_test.dart`
- `test/features/home/data/repositories/prayer_times_repository_impl_test.dart`
- `test/features/home/domain/usecases/pre_cache_prayer_times_test.dart`
- `test/features/home/presentation/cubit/prayer_countdown_cubit_test.dart`
- `test/features/home/presentation/cubit/daily_prayer_context_cubit_test.dart`
- `lib/features/home/domain/usecases/pre_cache_prayer_times.dart`

### MODIFIED files
- `pubspec.yaml` — add `mocktail`, `bloc_test` to dev_dependencies
- `lib/features/home/data/datasources/local/prayer_times_local_data_source.dart` — fix `clearOldCache` parsing; add `getCachedKeysForMonth`
- `lib/features/home/data/datasources/remote/prayer_time_remote_data_source.dart` — add optional `year`/`month` query params
- `lib/features/home/domain/repositories/prayer_times_repository.dart` — rename `prayerTimesBackgroundPreCache` → `preCacheMonth`
- `lib/features/home/data/repositories/prayer_times_repository_impl.dart` — implement `preCacheMonth`
- `lib/features/home/presentation/cubit/daily_prayer_context_cubit.dart` — add `silent` flag
- `lib/features/home/presentation/cubit/prayer_countdown_state.dart` — add `silent` field to `PrayerCountdownRequestRefresh`
- `lib/features/home/presentation/cubit/prayer_countdown_cubit.dart` — nullable context, two-flag refresh, midnight trigger
- `lib/features/home/presentation/pages/home_page.dart` — wire silent refresh + fire-and-forget pre-cache
- `lib/features/home/home_di.dart` — register `PreCachePrayerTimes`

---

## Task 0: Add test dependencies

**Files:**
- Modify: `pubspec.yaml`

- [ ] **Step 0.1:** Edit `pubspec.yaml` — under `dev_dependencies`, add `mocktail` and `bloc_test`:
  ```yaml
  dev_dependencies:
    build_runner: ^2.4.13
    flutter_lints: ^6.0.0

    flutter_test:
      sdk: flutter

    hive_generator: ^2.0.1
    mocktail: ^1.0.4
    bloc_test: ^10.0.0
  ```

- [ ] **Step 0.2:** Run `flutter pub get`. Confirm exit code 0.

- [ ] **Step 0.3:** Commit:
  ```
  chore(test): add mocktail and bloc_test dev dependencies
  ```

---

## Task 1: Fix `clearOldCache` date-key parsing (TDD)

**Bug:** `DateTime.tryParse("28-05-2026")` always returns `null` — keys are `"dd-MM-yyyy"`, not ISO. Nothing is ever deleted from the cache.

**Files:**
- Create: `test/features/home/data/datasources/local/prayer_times_local_data_source_test.dart`
- Modify: `lib/features/home/data/datasources/local/prayer_times_local_data_source.dart`

- [ ] **Step 1.1 — Write the failing test:**
  Create `test/features/home/data/datasources/local/prayer_times_local_data_source_test.dart`:
  ```dart
  import 'dart:io';

  import 'package:flutter_test/flutter_test.dart';
  import 'package:hive/hive.dart';
  import 'package:quran_app/core/constants/prayers_list_constants.dart';
  import 'package:quran_app/features/home/data/datasources/local/prayer_times_local_data_source.dart';
  import 'package:quran_app/features/home/data/models/prayer_times_hive_model.dart';
  import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

  void main() {
    late Directory tempDir;
    late Box<PrayerTimesHiveModel> box;
    late PrayerTimesLocalDataSource ds;

    setUpAll(() async {
      tempDir = await Directory.systemTemp.createTemp('hive_test_');
      Hive.init(tempDir.path);
      if (!Hive.isAdapterRegistered(0)) {
        Hive.registerAdapter(PrayerTimesHiveModelAdapter());
      }
    });

    setUp(() async {
      box = await Hive.openBox<PrayerTimesHiveModel>(
        'prayerTimesCache_test_${DateTime.now().microsecondsSinceEpoch}',
      );
      ds = PrayerTimesLocalDataSource(prayerTimesBox: box);
    });

    tearDown(() async => box.deleteFromDisk());

    tearDownAll(() async {
      await Hive.close();
      await tempDir.delete(recursive: true);
    });

    PrayerTimes mkEntry(String ddMMyyyy) => PrayerTimes(
          key: ddMMyyyy,
          timings: const {
            PrayerName.fajr: '04:00',
            PrayerName.sunrise: '05:30',
            PrayerName.dhuhr: '12:00',
            PrayerName.asr: '15:30',
            PrayerName.maghrib: '18:00',
            PrayerName.isha: '19:30',
          },
          date: Date(
            month: '1', weekDay: 'Mon', year: '1446', day: '1',
            enMonth: 'Muharram', enWeekDay: 'Mon', gregorianDate: ddMMyyyy,
          ),
        );

    String fmt(DateTime d) =>
        '${d.day.toString().padLeft(2, '0')}-'
        '${d.month.toString().padLeft(2, '0')}-${d.year}';

    group('clearOldCache', () {
      test('deletes entries strictly before yesterday (dd-MM-yyyy keys)', () async {
        final now = DateTime.now();
        final older = fmt(now.subtract(const Duration(days: 10)));
        final yesterday = fmt(now.subtract(const Duration(days: 1)));
        final today = fmt(now);

        await ds.cache([mkEntry(older), mkEntry(yesterday), mkEntry(today)]);

        expect(box.containsKey(older), isFalse,
            reason: 'entry older than yesterday should be removed');
        expect(box.containsKey(yesterday), isTrue);
        expect(box.containsKey(today), isTrue);
      });

      test('keeps entries from a future month', () async {
        final now = DateTime.now();
        final future = DateTime(now.year, now.month + 2, 5);
        await ds.cache([mkEntry(fmt(future))]);
        expect(box.containsKey(fmt(future)), isTrue);
      });
    });
  }
  ```

- [ ] **Step 1.2 — Run (expect FAIL):**
  ```
  flutter test test/features/home/data/datasources/local/prayer_times_local_data_source_test.dart
  ```

- [ ] **Step 1.3 — Fix `clearOldCache`:**
  In `lib/features/home/data/datasources/local/prayer_times_local_data_source.dart`, replace the `clearOldCache` method body:
  ```dart
  Future<void> clearOldCache() async {
    final now = DateTime.now();
    final threshold = DateTime(now.year, now.month, now.day - 1);
    final formatter = DateFormat('dd-MM-yyyy', 'en');

    final keysToRemove = <dynamic>[];

    for (var key in prayerTimesBox.keys) {
      DateTime? keyDate;
      if (key is DateTime) {
        keyDate = key;
      } else if (key is String) {
        try {
          keyDate = formatter.parseStrict(key);
        } catch (_) {
          keyDate = null;
        }
      }

      if (keyDate != null && keyDate.isBefore(threshold)) {
        keysToRemove.add(key);
      }
    }

    if (keysToRemove.isNotEmpty) {
      await prayerTimesBox.deleteAll(keysToRemove);
    }
  }
  ```

- [ ] **Step 1.4 — Run (expect PASS):**
  ```
  flutter test test/features/home/data/datasources/local/prayer_times_local_data_source_test.dart
  ```

- [ ] **Step 1.5 — Commit:**
  ```
  fix(prayer-times): parse dd-MM-yyyy keys in clearOldCache so old entries actually get pruned
  ```

---

## Task 2: Add `getCachedKeysForMonth` to local data source (TDD)

Needed by the pre-cache logic to decide whether a target month is already fully cached.

**Files:**
- Modify: `test/features/home/data/datasources/local/prayer_times_local_data_source_test.dart`
- Modify: `lib/features/home/data/datasources/local/prayer_times_local_data_source.dart`

- [ ] **Step 2.1 — Append failing test:**
  Inside `main()` in the local data source test file, after the existing `group('clearOldCache', ...)`, add:
  ```dart
    group('getCachedKeysForMonth', () {
      test('returns only keys whose month/year match', () async {
        await ds.cache([
          mkEntry('01-05-2025'),
          mkEntry('15-05-2025'),
          mkEntry('02-06-2025'),
        ]);

        final mayKeys = ds.getCachedKeysForMonth(year: 2025, month: 5);
        expect(mayKeys, containsAll(<String>['01-05-2025', '15-05-2025']));
        expect(mayKeys, isNot(contains('02-06-2025')));

        final juneKeys = ds.getCachedKeysForMonth(year: 2025, month: 6);
        expect(juneKeys, equals(<String>['02-06-2025']));

        final julyKeys = ds.getCachedKeysForMonth(year: 2025, month: 7);
        expect(julyKeys, isEmpty);
      });
    });
  ```

- [ ] **Step 2.2 — Run (expect FAIL — method missing):**
  ```
  flutter test test/features/home/data/datasources/local/prayer_times_local_data_source_test.dart
  ```

- [ ] **Step 2.3 — Add method to local data source:**
  In `lib/features/home/data/datasources/local/prayer_times_local_data_source.dart`, add this method to the class (above `clearCache`):
  ```dart
  List<String> getCachedKeysForMonth({required int year, required int month}) {
    final formatter = DateFormat('dd-MM-yyyy', 'en');
    final result = <String>[];
    for (var key in prayerTimesBox.keys) {
      if (key is! String) continue;
      DateTime? parsed;
      try {
        parsed = formatter.parseStrict(key);
      } catch (_) {
        continue;
      }
      if (parsed.year == year && parsed.month == month) {
        result.add(key);
      }
    }
    return result;
  }
  ```

- [ ] **Step 2.4 — Run (expect PASS):**
  ```
  flutter test test/features/home/data/datasources/local/prayer_times_local_data_source_test.dart
  ```

- [ ] **Step 2.5 — Commit:**
  ```
  feat(prayer-times): add getCachedKeysForMonth helper to local data source
  ```

---

## Task 3: Add `year`/`month` query params to remote data source (TDD)

The Aladhan `/v1/calendar` endpoint supports `?month=MM&year=YYYY`. Without them it returns the current month only, making it impossible to pre-cache next month proactively.

**Files:**
- Create: `test/features/home/data/datasources/remote/prayer_time_remote_data_source_test.dart`
- Modify: `lib/features/home/data/datasources/remote/prayer_time_remote_data_source.dart`

- [ ] **Step 3.1 — Write the failing test:**
  Create `test/features/home/data/datasources/remote/prayer_time_remote_data_source_test.dart`:
  ```dart
  import 'package:dio/dio.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:mocktail/mocktail.dart';
  import 'package:quran_app/features/home/data/datasources/remote/prayer_time_remote_data_source.dart';
  import 'package:quran_app/features/home/domain/entities/location.dart';

  class _MockDio extends Mock implements Dio {}

  void main() {
    late _MockDio dio;
    late PrayerTimeRemoteDataSource ds;

    setUp(() {
      dio = _MockDio();
      ds = PrayerTimeRemoteDataSource(dio: dio);
    });

    final location = Location(latitude: 30.0, longitude: 31.2);

    Response<dynamic> emptyResponse() => Response(
          data: {'data': <Map<String, dynamic>>[]},
          statusCode: 200,
          requestOptions: RequestOptions(path: ''),
        );

    test('without year/month: sends only lat/lng', () async {
      when(() => dio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => emptyResponse());

      await ds.getPrayerTimesList(location);

      final captured = verify(() => dio.get(
            'http://api.aladhan.com/v1/calendar',
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured.single as Map<String, dynamic>;

      expect(captured['latitude'], 30.0);
      expect(captured['longitude'], 31.2);
      expect(captured.containsKey('month'), isFalse);
      expect(captured.containsKey('year'), isFalse);
    });

    test('with year/month: forwards them to the API', () async {
      when(() => dio.get(
            any(),
            queryParameters: any(named: 'queryParameters'),
          )).thenAnswer((_) async => emptyResponse());

      await ds.getPrayerTimesList(location, year: 2025, month: 6);

      final captured = verify(() => dio.get(
            'http://api.aladhan.com/v1/calendar',
            queryParameters: captureAny(named: 'queryParameters'),
          )).captured.single as Map<String, dynamic>;

      expect(captured['latitude'], 30.0);
      expect(captured['longitude'], 31.2);
      expect(captured['month'], 6);
      expect(captured['year'], 2025);
    });
  }
  ```

- [ ] **Step 3.2 — Run (expect FAIL):**
  ```
  flutter test test/features/home/data/datasources/remote/prayer_time_remote_data_source_test.dart
  ```

- [ ] **Step 3.3 — Implement:**
  Replace `lib/features/home/data/datasources/remote/prayer_time_remote_data_source.dart`:
  ```dart
  import 'package:dio/dio.dart';
  import 'package:quran_app/features/home/data/models/prayer_times_model.dart';
  import 'package:quran_app/features/home/domain/entities/location.dart';
  import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

  class PrayerTimeRemoteDataSource {
    final Dio dio;
    PrayerTimeRemoteDataSource({required this.dio});

    Future<List<PrayerTimes>> getPrayerTimesList(
      Location location, {
      int? year,
      int? month,
    }) async {
      final queryParameters = <String, dynamic>{
        'latitude': location.latitude,
        'longitude': location.longitude,
      };
      if (year != null) queryParameters['year'] = year;
      if (month != null) queryParameters['month'] = month;

      final Response prayerTimesResponse = await dio.get(
        'http://api.aladhan.com/v1/calendar',
        queryParameters: queryParameters,
      );
      final prayerTimesResponseData = prayerTimesResponse.data['data'];
      return prayerTimesResponseData
          .map<PrayerTimesModel>(
            (dayPrayerTimes) => PrayerTimesModel.fromJson(dayPrayerTimes),
          )
          .toList();
    }
  }
  ```

- [ ] **Step 3.4 — Run (expect PASS):**
  ```
  flutter test test/features/home/data/datasources/remote/prayer_time_remote_data_source_test.dart
  ```

- [ ] **Step 3.5 — Commit:**
  ```
  feat(prayer-times): support year/month params in remote data source for next-month pre-cache
  ```

---

## Task 4: Replace dead `prayerTimesBackgroundPreCache` with `preCacheMonth` (TDD)

The old method always re-fetched the current month and was never called. The new `preCacheMonth(year, month)` checks whether the month is already fully cached before hitting the network.

**Files:**
- Create: `test/features/home/data/repositories/prayer_times_repository_impl_test.dart`
- Modify: `lib/features/home/domain/repositories/prayer_times_repository.dart`
- Modify: `lib/features/home/data/repositories/prayer_times_repository_impl.dart`

- [ ] **Step 4.1 — Write the failing test:**
  Create `test/features/home/data/repositories/prayer_times_repository_impl_test.dart`:
  ```dart
  import 'package:dio/dio.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:mocktail/mocktail.dart';
  import 'package:quran_app/core/constants/prayers_list_constants.dart';
  import 'package:quran_app/features/home/data/datasources/local/prayer_times_local_data_source.dart';
  import 'package:quran_app/features/home/data/datasources/remote/prayer_time_remote_data_source.dart';
  import 'package:quran_app/features/home/data/repositories/prayer_times_repository_impl.dart';
  import 'package:quran_app/features/home/domain/entities/location.dart';
  import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

  class _MockRemote extends Mock implements PrayerTimeRemoteDataSource {}
  class _MockLocal extends Mock implements PrayerTimesLocalDataSource {}

  void main() {
    late _MockRemote remote;
    late _MockLocal local;
    late PrayerTimesRepositoryImpl repo;

    setUpAll(() {
      registerFallbackValue(Location(latitude: 0, longitude: 0));
      registerFallbackValue(<PrayerTimes>[]);
    });

    setUp(() {
      remote = _MockRemote();
      local = _MockLocal();
      repo = PrayerTimesRepositoryImpl(
        prayerTimeRemoteDataSource: remote,
        prayerTimesLocalDataSource: local,
      );
    });

    final location = Location(latitude: 30.0, longitude: 31.2);

    PrayerTimes mk(String key) => PrayerTimes(
          key: key,
          timings: const {
            PrayerName.fajr: '04:00', PrayerName.sunrise: '05:30',
            PrayerName.dhuhr: '12:00', PrayerName.asr: '15:30',
            PrayerName.maghrib: '18:00', PrayerName.isha: '19:30',
          },
          date: Date(
            month: '1', weekDay: 'Mon', year: '1446', day: '1',
            enMonth: 'Muharram', enWeekDay: 'Mon', gregorianDate: key,
          ),
        );

    group('preCacheMonth', () {
      test('skips network when month is already fully cached', () async {
        // June has 30 days
        final cachedKeys = List<String>.generate(
          30,
          (i) => '${(i + 1).toString().padLeft(2, '0')}-06-2025',
        );
        when(() => local.getCachedKeysForMonth(year: 2025, month: 6))
            .thenReturn(cachedKeys);

        await repo.preCacheMonth(location: location, year: 2025, month: 6);

        verifyNever(() => remote.getPrayerTimesList(
              any(),
              year: any(named: 'year'),
              month: any(named: 'month'),
            ));
      });

      test('fetches and caches when target month is missing', () async {
        when(() => local.getCachedKeysForMonth(year: 2025, month: 7))
            .thenReturn(<String>[]);
        when(() => remote.getPrayerTimesList(
              any(),
              year: any(named: 'year'),
              month: any(named: 'month'),
            )).thenAnswer((_) async => [mk('01-07-2025')]);
        when(() => local.cache(any())).thenAnswer((_) async {});

        await repo.preCacheMonth(location: location, year: 2025, month: 7);

        verify(() => remote.getPrayerTimesList(
              location,
              year: 2025,
              month: 7,
            )).called(1);
        verify(() => local.cache(any())).called(1);
      });

      test('swallows DioException without throwing', () async {
        when(() => local.getCachedKeysForMonth(year: 2025, month: 7))
            .thenReturn(<String>[]);
        when(() => remote.getPrayerTimesList(
              any(),
              year: any(named: 'year'),
              month: any(named: 'month'),
            )).thenThrow(DioException(
          requestOptions: RequestOptions(path: ''),
        ));

        await expectLater(
          repo.preCacheMonth(location: location, year: 2025, month: 7),
          completes,
        );
      });
    });
  }
  ```

- [ ] **Step 4.2 — Run (expect FAIL — `preCacheMonth` doesn't exist):**
  ```
  flutter test test/features/home/data/repositories/prayer_times_repository_impl_test.dart
  ```

- [ ] **Step 4.3 — Update abstract repository:**
  Replace `lib/features/home/domain/repositories/prayer_times_repository.dart`:
  ```dart
  import 'package:dartz/dartz.dart';
  import 'package:quran_app/core/errors/failure.dart';
  import 'package:quran_app/features/home/domain/entities/location.dart';
  import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

  abstract class PrayerTimesRepository {
    Future<Either<Failure, PrayerTimes>> getPrayerTimes(Location location);

    /// Pre-caches the given month. Skips network if already fully cached.
    /// Never throws — failures are silently swallowed.
    Future<void> preCacheMonth({
      required Location location,
      required int year,
      required int month,
    });
  }
  ```

- [ ] **Step 4.4 — Update repository impl:**
  Replace `lib/features/home/data/repositories/prayer_times_repository_impl.dart`:
  ```dart
  import 'package:dartz/dartz.dart';
  import 'package:dio/dio.dart';
  import 'package:quran_app/core/constants/prayers_list_constants.dart';
  import 'package:quran_app/core/errors/failure.dart';
  import 'package:quran_app/core/helper%20functions/time_helpers.dart';
  import 'package:quran_app/core/utils/dio_error_handler.dart';
  import 'package:quran_app/features/home/data/datasources/local/prayer_times_local_data_source.dart';
  import 'package:quran_app/features/home/data/datasources/remote/prayer_time_remote_data_source.dart';
  import 'package:quran_app/features/home/domain/entities/location.dart';
  import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
  import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';

  class PrayerTimesRepositoryImpl extends PrayerTimesRepository {
    final PrayerTimeRemoteDataSource prayerTimeRemoteDataSource;
    final PrayerTimesLocalDataSource prayerTimesLocalDataSource;

    PrayerTimesRepositoryImpl({
      required this.prayerTimeRemoteDataSource,
      required this.prayerTimesLocalDataSource,
    });

    @override
    Future<Either<Failure, PrayerTimes>> getPrayerTimes(
      Location location,
    ) async {
      final now = DateTime.now();
      final todayData = prayerTimesLocalDataSource.getCached(date: now);

      if (todayData == null) {
        return _fetchAndCacheRemote(location, now);
      }

      final ishaTime = todayData.timings[PrayerName.isha]!.parse24hTime();
      if (now.isAfter(ishaTime)) {
        final tomorrowDate = now.add(const Duration(days: 1));
        final tomorrowData =
            prayerTimesLocalDataSource.getCached(date: tomorrowDate);

        if (tomorrowData != null) {
          return Right(
            PrayerTimes(
              key: todayData.key,
              date: todayData.date,
              timings: tomorrowData.timings,
            ),
          );
        }
      }

      return Right(todayData);
    }

    Future<Either<Failure, PrayerTimes>> _fetchAndCacheRemote(
      Location location,
      DateTime targetDate,
    ) async {
      try {
        final List<PrayerTimes> prayerTimesList =
            await prayerTimeRemoteDataSource.getPrayerTimesList(location);
        await prayerTimesLocalDataSource.cache(prayerTimesList);
        return Right(
          prayerTimesLocalDataSource.getCached(date: targetDate)!,
        );
      } on DioException catch (e) {
        return left(DioErrorHandler.handle(e));
      } catch (e) {
        return left(UnknownFailure(e.toString()));
      }
    }

    @override
    Future<void> preCacheMonth({
      required Location location,
      required int year,
      required int month,
    }) async {
      final daysInMonth = DateTime(year, month + 1, 0).day;
      final cachedKeys = prayerTimesLocalDataSource.getCachedKeysForMonth(
        year: year,
        month: month,
      );
      if (cachedKeys.length >= daysInMonth) return;

      try {
        final List<PrayerTimes> prayerTimesList =
            await prayerTimeRemoteDataSource.getPrayerTimesList(
          location,
          year: year,
          month: month,
        );
        await prayerTimesLocalDataSource.cache(prayerTimesList);
      } catch (_) {
        return;
      }
    }
  }
  ```

- [ ] **Step 4.5 — Run (expect PASS):**
  ```
  flutter test test/features/home/data/repositories/prayer_times_repository_impl_test.dart
  ```

- [ ] **Step 4.6 — Run data source tests for regression:**
  ```
  flutter test test/features/home/data/datasources/
  ```

- [ ] **Step 4.7 — Commit:**
  ```
  feat(prayer-times): replace dead prayerTimesBackgroundPreCache with preCacheMonth(year,month)
  ```

---

## Task 5: Create `PreCachePrayerTimes` use case (TDD)

Takes a `Location`, decides whether to also pre-cache the next month (within last 7 days of current month), and delegates to `repo.preCacheMonth`. Returns void — fire-and-forget.

**Files:**
- Create: `test/features/home/domain/usecases/pre_cache_prayer_times_test.dart`
- Create: `lib/features/home/domain/usecases/pre_cache_prayer_times.dart`

- [ ] **Step 5.1 — Write the failing test:**
  Create `test/features/home/domain/usecases/pre_cache_prayer_times_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:mocktail/mocktail.dart';
  import 'package:quran_app/features/home/domain/entities/location.dart';
  import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';
  import 'package:quran_app/features/home/domain/usecases/pre_cache_prayer_times.dart';

  class _MockRepo extends Mock implements PrayerTimesRepository {}

  void main() {
    late _MockRepo repo;
    late PreCachePrayerTimes usecase;

    setUpAll(() {
      registerFallbackValue(Location(latitude: 0, longitude: 0));
    });

    setUp(() {
      repo = _MockRepo();
      when(() => repo.preCacheMonth(
            location: any(named: 'location'),
            year: any(named: 'year'),
            month: any(named: 'month'),
          )).thenAnswer((_) async {});
      usecase = PreCachePrayerTimes(prayerTimesRepository: repo);
    });

    final location = Location(latitude: 30, longitude: 31);

    test('mid-month: pre-caches only current month', () async {
      // 15 May 2025: daysLeft = 31 - 15 = 16 > 7
      await usecase.call(PreCachePrayerTimesParams(
        location: location,
        now: DateTime(2025, 5, 15, 10),
      ));

      verify(() => repo.preCacheMonth(
            location: location,
            year: 2025,
            month: 5,
          )).called(1);
      verifyNever(() => repo.preCacheMonth(
            location: any(named: 'location'),
            year: 2025,
            month: 6,
          ));
    });

    test('within last 7 days of month: pre-caches current AND next month',
        () async {
      // 28 May 2025: daysLeft = 31 - 28 = 3 <= 7
      await usecase.call(PreCachePrayerTimesParams(
        location: location,
        now: DateTime(2025, 5, 28, 10),
      ));

      verify(() => repo.preCacheMonth(
            location: location,
            year: 2025,
            month: 5,
          )).called(1);
      verify(() => repo.preCacheMonth(
            location: location,
            year: 2025,
            month: 6,
          )).called(1);
    });

    test('December rollover: next month is January of next year', () async {
      // 30 Dec 2025: daysLeft = 31 - 30 = 1 <= 7
      await usecase.call(PreCachePrayerTimesParams(
        location: location,
        now: DateTime(2025, 12, 30, 10),
      ));

      verify(() => repo.preCacheMonth(
            location: location,
            year: 2025,
            month: 12,
          )).called(1);
      verify(() => repo.preCacheMonth(
            location: location,
            year: 2026,
            month: 1,
          )).called(1);
    });
  }
  ```

- [ ] **Step 5.2 — Run (expect FAIL — use case doesn't exist):**
  ```
  flutter test test/features/home/domain/usecases/pre_cache_prayer_times_test.dart
  ```

- [ ] **Step 5.3 — Create the use case:**
  Create `lib/features/home/domain/usecases/pre_cache_prayer_times.dart`:
  ```dart
  import 'package:quran_app/core/usecases/usecase.dart';
  import 'package:quran_app/features/home/domain/entities/location.dart';
  import 'package:quran_app/features/home/domain/repositories/prayer_times_repository.dart';

  class PreCachePrayerTimesParams {
    final Location location;
    final DateTime? now;
    PreCachePrayerTimesParams({required this.location, this.now});
  }

  class PreCachePrayerTimes extends UseCase<void, PreCachePrayerTimesParams> {
    final PrayerTimesRepository prayerTimesRepository;

    PreCachePrayerTimes({required this.prayerTimesRepository});

    static int _daysInMonth(int year, int month) =>
        DateTime(year, month + 1, 0).day;

    @override
    Future<void> call(PreCachePrayerTimesParams params) async {
      final now = params.now ?? DateTime.now();

      await prayerTimesRepository.preCacheMonth(
        location: params.location,
        year: now.year,
        month: now.month,
      );

      final daysLeft = _daysInMonth(now.year, now.month) - now.day;
      if (daysLeft <= 7) {
        final nextMonth = now.month == 12 ? 1 : now.month + 1;
        final nextYear = now.month == 12 ? now.year + 1 : now.year;
        await prayerTimesRepository.preCacheMonth(
          location: params.location,
          year: nextYear,
          month: nextMonth,
        );
      }
    }
  }
  ```

- [ ] **Step 5.4 — Run (expect PASS):**
  ```
  flutter test test/features/home/domain/usecases/pre_cache_prayer_times_test.dart
  ```

- [ ] **Step 5.5 — Commit:**
  ```
  feat(prayer-times): add PreCachePrayerTimes use case (current month + next month near month-end)
  ```

---

## Task 6: Add `silent` flag to `DailyPrayerContextCubit` (TDD)

**Files:**
- Create: `test/features/home/presentation/cubit/daily_prayer_context_cubit_test.dart`
- Modify: `lib/features/home/presentation/cubit/daily_prayer_context_cubit.dart`

- [ ] **Step 6.1 — Write the failing test:**
  Create `test/features/home/presentation/cubit/daily_prayer_context_cubit_test.dart`:
  ```dart
  import 'package:bloc_test/bloc_test.dart';
  import 'package:dartz/dartz.dart';
  import 'package:flutter_test/flutter_test.dart';
  import 'package:mocktail/mocktail.dart';
  import 'package:quran_app/core/constants/prayers_list_constants.dart';
  import 'package:quran_app/core/errors/failure.dart';
  import 'package:quran_app/core/usecases/usecase.dart';
  import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';
  import 'package:quran_app/features/home/domain/entities/location.dart';
  import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
  import 'package:quran_app/features/home/domain/usecases/get_daily_prayer_context.dart';
  import 'package:quran_app/features/home/presentation/cubit/daily_prayer_context_cubit.dart';

  class _MockGetDailyPrayerContext extends Mock
      implements GetDailyPrayerContext {}

  void main() {
    late _MockGetDailyPrayerContext usecase;

    setUpAll(() {
      registerFallbackValue(NoParams());
    });

    setUp(() {
      usecase = _MockGetDailyPrayerContext();
    });

    final loc = Location(latitude: 30, longitude: 31);
    final ctx = DailyPrayerContext(
      location: loc,
      date: '15-05-2025',
      prayerTimes: PrayerTimes(
        key: '15-05-2025',
        timings: const {
          PrayerName.fajr: '04:00', PrayerName.sunrise: '05:30',
          PrayerName.dhuhr: '12:00', PrayerName.asr: '15:30',
          PrayerName.maghrib: '18:00', PrayerName.isha: '19:30',
        },
        date: Date(
          month: '1', weekDay: 'Mon', year: '1446', day: '1',
          enMonth: 'Muharram', enWeekDay: 'Mon', gregorianDate: '15-05-2025',
        ),
      ),
    );

    blocTest<DailyPrayerContextCubit, DailyPrayerContextState>(
      'fetchDailyPrayerContext: emits Loading then Loaded',
      build: () {
        when(() => usecase.call(any()))
            .thenAnswer((_) => Stream.value(Right(ctx)));
        return DailyPrayerContextCubit(getDailyPrayerContext: usecase);
      },
      act: (c) => c.fetchDailyPrayerContext(),
      expect: () => [
        isA<DailyPrayerContextLoading>(),
        isA<DailyPrayerContextLoaded>(),
      ],
    );

    blocTest<DailyPrayerContextCubit, DailyPrayerContextState>(
      'fetchDailyPrayerContext(silent: true): skips Loading, emits only Loaded',
      build: () {
        when(() => usecase.call(any()))
            .thenAnswer((_) => Stream.value(Right(ctx)));
        return DailyPrayerContextCubit(getDailyPrayerContext: usecase);
      },
      act: (c) => c.fetchDailyPrayerContext(silent: true),
      expect: () => [isA<DailyPrayerContextLoaded>()],
    );

    blocTest<DailyPrayerContextCubit, DailyPrayerContextState>(
      'fetchDailyPrayerContext: emits Loading then Failed on Left',
      build: () {
        when(() => usecase.call(any())).thenAnswer(
          (_) => Stream.value(const Left(UnknownFailure('boom'))),
        );
        return DailyPrayerContextCubit(getDailyPrayerContext: usecase);
      },
      act: (c) => c.fetchDailyPrayerContext(),
      expect: () => [
        isA<DailyPrayerContextLoading>(),
        isA<DailyPrayerContextFailed>(),
      ],
    );
  }
  ```

- [ ] **Step 6.2 — Run (expect FAIL — `silent` param missing):**
  ```
  flutter test test/features/home/presentation/cubit/daily_prayer_context_cubit_test.dart
  ```

- [ ] **Step 6.3 — Implement:**
  Replace `lib/features/home/presentation/cubit/daily_prayer_context_cubit.dart`:
  ```dart
  import 'package:equatable/equatable.dart';
  import 'package:flutter_bloc/flutter_bloc.dart';
  import 'package:quran_app/core/usecases/usecase.dart';
  import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';
  import 'package:quran_app/features/home/domain/usecases/get_daily_prayer_context.dart';

  part 'daily_prayer_context_state.dart';

  class DailyPrayerContextCubit extends Cubit<DailyPrayerContextState> {
    DailyPrayerContextCubit({required this.getDailyPrayerContext})
        : super(DailyPrayerContextInitial());

    final GetDailyPrayerContext getDailyPrayerContext;

    /// [silent]: when true, suppresses [DailyPrayerContextLoading].
    /// Used by after-Isha and midnight auto-refreshes to avoid a UI flash.
    Future<void> fetchDailyPrayerContext({bool silent = false}) async {
      if (!silent) emit(DailyPrayerContextLoading());

      await getDailyPrayerContext(NoParams()).forEach((result) {
        if (isClosed) return;
        result.fold(
          (failure) => emit(DailyPrayerContextFailed(failure.message)),
          (dailyPrayerContext) =>
              emit(DailyPrayerContextLoaded(dailyPrayerContext)),
        );
      });
    }
  }
  ```

- [ ] **Step 6.4 — Run (expect PASS):**
  ```
  flutter test test/features/home/presentation/cubit/daily_prayer_context_cubit_test.dart
  ```

- [ ] **Step 6.5 — Commit:**
  ```
  feat(prayer-context): add silent flag to fetchDailyPrayerContext to suppress loading flash
  ```

---

## Task 7: Add `silent` field to `PrayerCountdownRequestRefresh` state

No separate test — behavior is exercised end-to-end in Task 8.

**Files:**
- Modify: `lib/features/home/presentation/cubit/prayer_countdown_state.dart`

- [ ] **Step 7.1 — Replace the file:**
  ```dart
  part of 'prayer_countdown_cubit.dart';

  abstract class PrayerCountdownState extends Equatable {
    @override
    List<Object> get props => [];
  }

  class PrayerCountdownInitial extends PrayerCountdownState {}

  class PrayerCountdownTick extends PrayerCountdownState {
    final PrayerCountdown prayerCountdown;
    PrayerCountdownTick(this.prayerCountdown);
    @override
    List<Object> get props => [prayerCountdown];
  }

  class PrayerCountdownRequestRefresh extends PrayerCountdownState {
    final bool silent;
    PrayerCountdownRequestRefresh({this.silent = true});
    @override
    List<Object> get props => [silent];
  }
  ```

- [ ] **Step 7.2 — Analyze (compile check):**
  ```
  flutter analyze lib/features/home/presentation/cubit/
  ```
  Expected: errors in `prayer_countdown_cubit.dart` because it still references `_isRefreshed`. These are fixed in Task 8.

> Do NOT commit yet — combine with Task 8.

---

## Task 8: Fix `PrayerCountdownCubit` — nullable context, two-flag refresh, midnight trigger (TDD)

**Critical design rule for `startTimer`:** Flags are reset **only when the context's gregorian date changes**. If the same-day date reloads (after-Isha refresh returns today's date + tomorrow's timings), flags are preserved — otherwise the after-Isha condition re-fires immediately causing an infinite refresh loop.

**Files:**
- Create: `test/features/home/presentation/cubit/prayer_countdown_cubit_test.dart`
- Modify: `lib/features/home/presentation/cubit/prayer_countdown_cubit.dart`

- [ ] **Step 8.1 — Write the failing test:**
  Create `test/features/home/presentation/cubit/prayer_countdown_cubit_test.dart`:
  ```dart
  import 'package:flutter_test/flutter_test.dart';
  import 'package:quran_app/core/constants/prayers_list_constants.dart';
  import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';
  import 'package:quran_app/features/home/domain/entities/location.dart';
  import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
  import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';

  DailyPrayerContext ctxFor(DateTime d, {int ishaHour = 19}) {
    String two(int n) => n.toString().padLeft(2, '0');
    final key = '${two(d.day)}-${two(d.month)}-${d.year}';
    return DailyPrayerContext(
      location: Location(latitude: 30, longitude: 31),
      date: key,
      prayerTimes: PrayerTimes(
        key: key,
        timings: {
          PrayerName.fajr: '04:00',
          PrayerName.sunrise: '05:30',
          PrayerName.dhuhr: '12:00',
          PrayerName.asr: '15:30',
          PrayerName.maghrib: '18:00',
          PrayerName.isha: '${two(ishaHour)}:00',
        },
        date: Date(
          month: '1', weekDay: 'Mon', year: '1446', day: '1',
          enMonth: 'Muharram', enWeekDay: 'Mon', gregorianDate: key,
        ),
      ),
    );
  }

  void main() {
    test('no crash before startTimer is called', () async {
      final cubit = PrayerCountdownCubit();
      expect(cubit.state, isA<PrayerCountdownInitial>());
      await cubit.close();
    });

    test(
        'after Isha on same day: emits Tick then one silent RequestRefresh',
        () async {
      final cubit = PrayerCountdownCubit();
      final today = DateTime.now();
      // ishaHour=0 → "00:00", so now (any reasonable time) is always after isha
      final ctx = ctxFor(today, ishaHour: 0);

      final emitted = <PrayerCountdownState>[];
      final sub = cubit.stream.listen(emitted.add);

      cubit.startTimer(ctx);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emitted.whereType<PrayerCountdownTick>().isNotEmpty, isTrue);
      final refreshes = emitted.whereType<PrayerCountdownRequestRefresh>().toList();
      expect(refreshes, hasLength(1));
      expect(refreshes.first.silent, isTrue);

      await sub.cancel();
      await cubit.close();
    });

    test(
        'same-day reload after Isha: startTimer with same date does NOT re-fire refresh',
        () async {
      final cubit = PrayerCountdownCubit();
      final today = DateTime.now();
      final ctx = ctxFor(today, ishaHour: 0);

      // First start — fires refresh
      cubit.startTimer(ctx);
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // Second start with SAME date (simulates after-Isha reload)
      final emitted = <PrayerCountdownState>[];
      final sub = cubit.stream.listen(emitted.add);

      cubit.startTimer(ctx); // same date → flags preserved
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        emitted.whereType<PrayerCountdownRequestRefresh>(),
        isEmpty,
        reason: 'same-day reload must not re-fire to avoid infinite loop',
      );

      await sub.cancel();
      await cubit.close();
    });

    test(
        'midnight crossing: context date behind device date fires one silent refresh',
        () async {
      final cubit = PrayerCountdownCubit();
      // Use yesterday's context so device day != context day
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      final ctx = ctxFor(yesterday, ishaHour: 23);

      final emitted = <PrayerCountdownState>[];
      final sub = cubit.stream.listen(emitted.add);

      cubit.startTimer(ctx);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      final refreshes = emitted.whereType<PrayerCountdownRequestRefresh>().toList();
      expect(refreshes, hasLength(1));
      expect(refreshes.first.silent, isTrue);

      await sub.cancel();
      await cubit.close();
    });

    test(
        'new-day context after midnight resets flags so next Isha can refresh',
        () async {
      final cubit = PrayerCountdownCubit();
      final today = DateTime.now();

      // 1st context: today after isha
      cubit.startTimer(ctxFor(today, ishaHour: 0));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      // 2nd context: next day (simulates midnight refresh result — different date)
      final tomorrow = today.add(const Duration(days: 1));
      final emitted = <PrayerCountdownState>[];
      final sub = cubit.stream.listen(emitted.add);

      cubit.startTimer(ctxFor(tomorrow, ishaHour: 0));
      await Future<void>.delayed(const Duration(milliseconds: 30));

      expect(
        emitted.whereType<PrayerCountdownRequestRefresh>().length,
        greaterThanOrEqualTo(1),
        reason: 'new-day context resets flags → Isha refresh fires again',
      );

      await sub.cancel();
      await cubit.close();
    });
  }
  ```

- [ ] **Step 8.2 — Run (expect FAIL):**
  ```
  flutter test test/features/home/presentation/cubit/prayer_countdown_cubit_test.dart
  ```

- [ ] **Step 8.3 — Implement:**
  Replace `lib/features/home/presentation/cubit/prayer_countdown_cubit.dart`:
  ```dart
  import 'dart:async';

  import 'package:equatable/equatable.dart';
  import 'package:flutter_animate/flutter_animate.dart';
  import 'package:flutter_bloc/flutter_bloc.dart';
  import 'package:quran_app/core/constants/prayers_list_constants.dart';
  import 'package:quran_app/core/helper%20functions/time_helpers.dart';
  import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';
  import 'package:quran_app/features/home/domain/entities/prayer_countdown.dart';

  part 'prayer_countdown_state.dart';

  class PrayerCountdownCubit extends Cubit<PrayerCountdownState> {
    PrayerCountdownCubit() : super(PrayerCountdownInitial());

    DailyPrayerContext? _dailyPrayerContext;

    Timer? _timer;

    /// Prevents re-firing after-Isha refresh on the same gregorian day.
    bool _isAfterIshaRefreshed = false;

    /// Prevents re-firing midnight refresh while the stale context is still loaded.
    bool _isMidnightRefreshed = false;

    void startTimer(DailyPrayerContext dailyPrayerContext) {
      final prevDate = _dailyPrayerContext?.date;
      _dailyPrayerContext = dailyPrayerContext;

      // Reset flags ONLY when the gregorian date actually changes (new calendar day).
      // When the same date reloads (e.g. after-Isha returns today's date + tomorrow's
      // timings), flags are preserved to prevent an immediate re-fire.
      if (prevDate == null || prevDate != dailyPrayerContext.date) {
        _isAfterIshaRefreshed = false;
        _isMidnightRefreshed = false;
      }

      _timer?.cancel();
      _emitTick();
      _timer = Timer.periodic(1.seconds, (_) => _emitTick());
    }

    void _emitTick() {
      final ctx = _dailyPrayerContext;
      if (ctx == null) return;

      final now = DateTime.now();
      final contextDate = ctx.date.gregorianDate();

      PrayerName currentPrayer = PrayerName.isha;
      PrayerName nextPrayer = PrayerName.fajr;

      DateTime targetNextPrayerTime = ctx.prayerTimes
          .timings[PrayerName.fajr]!
          .parse24hTime(date: contextDate)
          .add(1.days);

      for (final prayerName in prayersList) {
        final prayerTime =
            ctx.prayerTimes.timings[prayerName]!.parse24hTime(date: contextDate);

        if (now.isAfter(prayerTime)) {
          currentPrayer = prayerName;
          continue;
        }
        if (now.isBefore(prayerTime)) {
          targetNextPrayerTime = prayerTime;
          nextPrayer = prayerName;
          break;
        }
      }

      emit(
        PrayerCountdownTick(
          PrayerCountdown(
            currentPrayer: currentPrayer,
            nextPrayer: nextPrayer,
            remainingTime: targetNextPrayerTime.difference(now),
          ),
        ),
      );

      // After-Isha refresh: still same gregorian day, current prayer is Isha.
      if (currentPrayer == PrayerName.isha &&
          now.day == contextDate.day &&
          now.month == contextDate.month &&
          now.year == contextDate.year &&
          !_isAfterIshaRefreshed) {
        _isAfterIshaRefreshed = true;
        emit(PrayerCountdownRequestRefresh(silent: true));
        return;
      }

      // Midnight refresh: device clock rolled into a new gregorian day.
      if ((now.day != contextDate.day ||
              now.month != contextDate.month ||
              now.year != contextDate.year) &&
          !_isMidnightRefreshed) {
        _isMidnightRefreshed = true;
        emit(PrayerCountdownRequestRefresh(silent: true));
      }
    }

    @override
    Future<void> close() {
      _timer?.cancel();
      return super.close();
    }
  }
  ```

- [ ] **Step 8.4 — Run (expect PASS):**
  ```
  flutter test test/features/home/presentation/cubit/prayer_countdown_cubit_test.dart
  ```

- [ ] **Step 8.5 — Run both cubit tests:**
  ```
  flutter test test/features/home/presentation/cubit/
  ```

- [ ] **Step 8.6 — Commit (Tasks 7 + 8 together):**
  ```
  fix(countdown): nullable context guard, silent two-flag refresh (after-Isha + midnight), no infinite loop
  ```

---

## Task 9: Wire silent refresh + fire-and-forget pre-cache in `HomePage`

**Files:**
- Modify: `lib/features/home/presentation/pages/home_page.dart`

- [ ] **Step 9.1 — Replace the file:**
  ```dart
  import 'dart:async';

  import 'package:flutter/material.dart';
  import 'package:flutter_bloc/flutter_bloc.dart';
  import 'package:quran_app/core/di/dependency_injection.dart';
  import 'package:quran_app/features/home/domain/usecases/pre_cache_prayer_times.dart';
  import 'package:quran_app/features/home/presentation/cubit/daily_prayer_context_cubit.dart';
  import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
  import 'package:quran_app/features/home/presentation/pages/widgets/home_view.dart';

  class HomePage extends StatelessWidget {
    const HomePage({super.key});

    @override
    Widget build(BuildContext context) {
      return MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (_) =>
                sl<DailyPrayerContextCubit>()..fetchDailyPrayerContext(),
          ),
          BlocProvider(create: (_) => PrayerCountdownCubit()),
        ],
        child: MultiBlocListener(
          listeners: [
            // Forward the silent flag from countdown cubit to context cubit.
            BlocListener<PrayerCountdownCubit, PrayerCountdownState>(
              listenWhen: (_, s) => s is PrayerCountdownRequestRefresh,
              listener: (context, state) {
                final s = state as PrayerCountdownRequestRefresh;
                context
                    .read<DailyPrayerContextCubit>()
                    .fetchDailyPrayerContext(silent: s.silent);
              },
            ),
            // Fire-and-forget pre-cache on every successful context load.
            BlocListener<DailyPrayerContextCubit, DailyPrayerContextState>(
              listenWhen: (_, s) => s is DailyPrayerContextLoaded,
              listener: (context, state) {
                final loaded = state as DailyPrayerContextLoaded;
                unawaited(
                  sl<PreCachePrayerTimes>().call(
                    PreCachePrayerTimesParams(
                      location: loaded.dailyPrayerContext.location,
                    ),
                  ),
                );
              },
            ),
          ],
          child: HomeView(),
        ),
      );
    }
  }
  ```

- [ ] **Step 9.2 — Analyze:**
  ```
  flutter analyze lib/features/home/presentation/pages/home_page.dart
  ```
  Expected: `sl<PreCachePrayerTimes>()` resolves at runtime; analyze passes.

> Hold the commit — do it together with Task 10.

---

## Task 10: Register `PreCachePrayerTimes` in DI

**Files:**
- Modify: `lib/features/home/home_di.dart`

- [ ] **Step 10.1 — Add import and registration:**
  Add import at top of `lib/features/home/home_di.dart`:
  ```dart
  import 'package:quran_app/features/home/domain/usecases/pre_cache_prayer_times.dart';
  ```
  Below the existing `GetDailyPrayerContext` registration, add:
  ```dart
  sl.registerLazySingleton(
    () => PreCachePrayerTimes(prayerTimesRepository: sl()),
  );
  ```
  The complete `initHome()` function becomes:
  ```dart
  void initHome() {
    final prayerTimesBox = Hive.box<PrayerTimesHiveModel>('prayerTimesCache');
    final locationHiveBox = Hive.box<LocationHiveModel>('userLocationCache');

    sl.registerLazySingleton(
      () => PrayerTimesLocalDataSource(prayerTimesBox: prayerTimesBox),
    );
    sl.registerLazySingleton(
      () => LocationLocalDataSource(locationHiveBox: locationHiveBox),
    );
    sl.registerLazySingleton(() => LocationRemoteDataSource(dio: sl()));
    sl.registerLazySingleton(() => PrayerTimeRemoteDataSource(dio: sl()));

    sl.registerLazySingleton<LocationRepository>(
      () => LocationRepositoryImpl(
        prayerTimesLocalDataSource: sl(),
        locationLocalDataSource: sl(),
        locationRemoteDataSource: sl(),
      ),
    );
    sl.registerLazySingleton<PrayerTimesRepository>(
      () => PrayerTimesRepositoryImpl(
        prayerTimeRemoteDataSource: sl(),
        prayerTimesLocalDataSource: sl(),
      ),
    );

    sl.registerLazySingleton(
      () => GetDailyPrayerContext(
        prayerTimesRepository: sl(),
        locationRepository: sl(),
      ),
    );

    sl.registerLazySingleton(
      () => PreCachePrayerTimes(prayerTimesRepository: sl()),
    );

    sl.registerFactory(
      () => DailyPrayerContextCubit(getDailyPrayerContext: sl()),
    );
  }
  ```

- [ ] **Step 10.2 — Full analyze:**
  ```
  flutter analyze
  ```

- [ ] **Step 10.3 — Full test suite:**
  ```
  flutter test
  ```

- [ ] **Step 10.4 — Commit (Tasks 9 + 10 together):**
  ```
  feat(home): wire PreCachePrayerTimes fire-and-forget on load + DI registration + silent refresh forwarding
  ```

---

## Task 11: Final regression sweep

- [ ] **Step 11.1:** `flutter test` — all tests green
- [ ] **Step 11.2:** `flutter analyze` — zero issues
- [ ] **Step 11.3 — Optional device smoke test:**
  - Device clock at 22:00 with Isha = 21:30 → open app → prayer list updates to tomorrow's times, NO spinner flash
  - Device clock past midnight → re-open app → date header and prayer list silently refresh to new day
  - Device date = 28th of month → cold open → after a few seconds, cache contains the following month's data
- [ ] **Step 11.4:** Final cleanup commit if needed:
  ```
  chore(prayer-times): final cleanup after refresh and monthly-cache fixes
  ```

---

## Key Invariants (must hold across all tasks)

| Invariant | Location |
|---|---|
| `_dailyPrayerContext` is `DailyPrayerContext?` with null-guard at top of `_emitTick` | `prayer_countdown_cubit.dart` |
| `startTimer` only resets refresh flags when `prevDate != newContext.date` | `prayer_countdown_cubit.dart` |
| `unawaited(...)` imported from `dart:async` | `home_page.dart` |
| `PreCachePrayerTimes.call` takes `PreCachePrayerTimesParams`, not `NoParams` | `pre_cache_prayer_times.dart` |
| `daysInMonth(y, m) == DateTime(y, m + 1, 0).day` | `pre_cache_prayer_times.dart`, `prayer_times_repository_impl.dart` |
| Domain layer (`domain/usecases/`) has no Flutter imports | `pre_cache_prayer_times.dart` |
| `PreCachePrayerTimes` registered as `LazySingleton` | `home_di.dart` |
