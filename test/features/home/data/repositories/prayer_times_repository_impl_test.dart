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
          PrayerName.fajr: '04:00',
          PrayerName.sunrise: '05:30',
          PrayerName.dhuhr: '12:00',
          PrayerName.asr: '15:30',
          PrayerName.maghrib: '18:00',
          PrayerName.isha: '19:30',
        },
        date: Date(
          month: '1',
          weekDay: 'Mon',
          year: '1446',
          day: '1',
          enMonth: 'Muharram',
          enWeekDay: 'Mon',
          gregorianDate: key,
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
