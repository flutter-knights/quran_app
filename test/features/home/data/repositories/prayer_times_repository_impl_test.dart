import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/features/home/data/datasources/local/prayer_config_signature.dart';
import 'package:quran_app/features/home/data/datasources/local/prayer_times_local_data_source.dart'
    show PrayerTimesLocalDataSource, formatKey;
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
  late Box box;

  setUpAll(() {
    registerFallbackValue(Location(latitude: 0, longitude: 0));
    registerFallbackValue(<PrayerTimes>[]);
  });

  setUp(() async {
    Hive.init('./.dart_tool/hive_test_${DateTime.now().microsecondsSinceEpoch}');
    box = await Hive.openBox('prayerConfig_test');
    remote = _MockRemote();
    local = _MockLocal();
    repo = PrayerTimesRepositoryImpl(
      prayerTimeRemoteDataSource: remote,
      prayerTimesLocalDataSource: local,
      signatureStore: PrayerConfigSignatureStore(box: box),
    );
  });

  tearDown(() async => box.deleteFromDisk());

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

  group('getPrayerTimes', () {
    test(
        'after-Isha: returns tomorrow wholesale (key, date, timings all from tomorrow)',
        () async {
      final now = DateTime.now();
      final tomorrow = now.add(const Duration(days: 1));

      final String todayKey = formatKey(date: now);
      final String tomorrowKey = formatKey(date: tomorrow);

      // Today's object has Isha at 00:01 so that DateTime.now() is always after it.
      final todayObj = PrayerTimes(
        key: todayKey,
        timings: {
          PrayerName.fajr: '00:00',
          PrayerName.sunrise: '00:00',
          PrayerName.dhuhr: '00:00',
          PrayerName.asr: '00:00',
          PrayerName.maghrib: '00:00',
          PrayerName.isha: '00:01',
        },
        date: Date(
          month: '1',
          weekDay: 'Mon',
          year: '1446',
          day: '1',
          enMonth: 'Muharram',
          enWeekDay: 'Mon',
          gregorianDate: todayKey,
        ),
      );

      // Tomorrow's object has distinct timings and its own key/gregorianDate.
      final tomorrowObj = PrayerTimes(
        key: tomorrowKey,
        timings: {
          PrayerName.fajr: '04:15',
          PrayerName.sunrise: '05:45',
          PrayerName.dhuhr: '12:15',
          PrayerName.asr: '15:45',
          PrayerName.maghrib: '18:15',
          PrayerName.isha: '19:45',
        },
        date: Date(
          month: '2',
          weekDay: 'Tue',
          year: '1446',
          day: '2',
          enMonth: 'Muharram',
          enWeekDay: 'Tue',
          gregorianDate: tomorrowKey,
        ),
      );

      // clearCache is called because the signature store has no prior value.
      when(() => local.clearCache()).thenReturn(null);

      // getCached dispatches by date: today → todayObj, tomorrow → tomorrowObj.
      when(() => local.getCached(date: any(named: 'date'))).thenAnswer((inv) {
        final d = inv.namedArguments[#date] as DateTime;
        final isTomorrow = d.year == tomorrow.year &&
            d.month == tomorrow.month &&
            d.day == tomorrow.day;
        return isTomorrow ? tomorrowObj : todayObj;
      });

      final result = await repo.getPrayerTimes(location);

      final pt = result.getOrElse(() => throw Exception('Expected Right'));

      expect(pt.key, equals(tomorrowKey),
          reason: 'key must come from tomorrow, not today');
      expect(pt.date.gregorianDate, equals(tomorrowKey),
          reason: 'gregorianDate must come from tomorrow');
      expect(pt.timings[PrayerName.isha], equals('19:45'),
          reason: 'timings must come from tomorrow wholesale');
    });
  });

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
            method: any(named: 'method'),
            school: any(named: 'school'),
          ));
    });

    test('fetches and caches when target month is missing', () async {
      when(() => local.getCachedKeysForMonth(year: 2025, month: 7))
          .thenReturn(<String>[]);
      when(() => remote.getPrayerTimesList(
            any(),
            year: any(named: 'year'),
            month: any(named: 'month'),
            method: any(named: 'method'),
            school: any(named: 'school'),
          )).thenAnswer((_) async => [mk('01-07-2025')]);
      when(() => local.cache(any())).thenAnswer((_) async {});

      await repo.preCacheMonth(location: location, year: 2025, month: 7);

      verify(() => remote.getPrayerTimesList(
            location,
            year: 2025,
            month: 7,
            method: any(named: 'method'),
            school: any(named: 'school'),
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
            method: any(named: 'method'),
            school: any(named: 'school'),
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
