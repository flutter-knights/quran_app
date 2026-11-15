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
    when(
      () => repo.preCacheMonth(
        location: any(named: 'location'),
        year: any(named: 'year'),
        month: any(named: 'month'),
      ),
    ).thenAnswer((_) async => false);
    usecase = PreCachePrayerTimes(prayerTimesRepository: repo);
  });

  final location = Location(latitude: 30, longitude: 31);

  test('mid-month: pre-caches current and next month', () async {
    await usecase.call(
      PreCachePrayerTimesParams(
        location: location,
        now: DateTime(2025, 5, 15, 10),
      ),
    );
    verify(
      () => repo.preCacheMonth(location: location, year: 2025, month: 5),
    ).called(1);
    verify(
      () => repo.preCacheMonth(location: location, year: 2025, month: 6),
    ).called(1);
  });

  test('end of month: pre-caches current and next month', () async {
    // 28 May 2025: daysLeft = 31 - 28 = 3 <= 7
    await usecase.call(
      PreCachePrayerTimesParams(
        location: location,
        now: DateTime(2025, 5, 28, 10),
      ),
    );

    verify(
      () => repo.preCacheMonth(location: location, year: 2025, month: 5),
    ).called(1);
    verify(
      () => repo.preCacheMonth(location: location, year: 2025, month: 6),
    ).called(1);
  });

  test('December rollover: next month is January of next year', () async {
    // 30 Dec 2025: daysLeft = 31 - 30 = 1 <= 7
    await usecase.call(
      PreCachePrayerTimesParams(
        location: location,
        now: DateTime(2025, 12, 30, 10),
      ),
    );

    verify(
      () => repo.preCacheMonth(location: location, year: 2025, month: 12),
    ).called(1);
    verify(
      () => repo.preCacheMonth(location: location, year: 2026, month: 1),
    ).called(1);
  });

  void fetches({required int month, required bool fetched}) {
    when(
      () => repo.preCacheMonth(
        location: any(named: 'location'),
        year: any(named: 'year'),
        month: month,
      ),
    ).thenAnswer((_) async => fetched);
  }

  final params = PreCachePrayerTimesParams(
    location: location,
    now: DateTime(2025, 5, 15, 10),
  );

  test('reports nothing fetched when both months were cached', () async {
    expect(await usecase.call(params), isFalse);
  });

  test(
    'reports a fetch of the current month and still fetches the next',
    () async {
      fetches(month: 5, fetched: true);
      expect(await usecase.call(params), isTrue);
      verify(
        () => repo.preCacheMonth(location: location, year: 2025, month: 6),
      ).called(1);
    },
  );

  test('reports a fetch of the next month', () async {
    fetches(month: 6, fetched: true);
    expect(await usecase.call(params), isTrue);
  });
}
