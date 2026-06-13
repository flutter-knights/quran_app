import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/data/datasources/local/prayer_times_local_data_source.dart';
import 'package:quran_app/features/home/data/datasources/remote/prayer_time_remote_data_source.dart';
import 'package:quran_app/features/home/data/repositories/prayer_times_repository_impl.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

class _MockLocal extends Mock implements PrayerTimesLocalDataSource {}
class _MockRemote extends Mock implements PrayerTimeRemoteDataSource {}

void main() {
  setUpAll(() {
    registerFallbackValue(Location(latitude: 0, longitude: 0));
  });

  late _MockLocal local;
  late _MockRemote remote;
  late PrayerTimesRepositoryImpl repo;

  final pt = PrayerTimes(
    key: '23-05-2026',
    timings: const {PrayerName.fajr: '04:14'},
    date: Date(
      month: '', weekDay: '', day: '6', year: '1447',
      enMonth: '', enWeekDay: '', gregorianDate: '23-05-2026',
    ),
  );

  setUp(() {
    local = _MockLocal();
    remote = _MockRemote();
    repo = PrayerTimesRepositoryImpl(
      prayerTimeRemoteDataSource: remote,
      prayerTimesLocalDataSource: local,
    );
  });

  test('returns the cached entry for the given date (no network)', () async {
    final date = DateTime(2026, 5, 23);
    when(() => local.getCached(date: date)).thenReturn(pt);
    final result = await repo.getCachedForDate(date);
    expect(result, pt);
    verifyNever(() => remote.getPrayerTimesList(any()));
  });

  test('returns null on a cache miss', () async {
    final date = DateTime(2026, 5, 23);
    when(() => local.getCached(date: date)).thenReturn(null);
    expect(await repo.getCachedForDate(date), isNull);
  });
}
