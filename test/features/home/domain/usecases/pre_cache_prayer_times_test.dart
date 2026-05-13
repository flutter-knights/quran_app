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
