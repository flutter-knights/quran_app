import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_cached_prayer_days.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_cubit.dart';

class _MockGetDays extends Mock implements GetCachedPrayerDays {}

void main() {
  late _MockGetDays getDays;
  final today = PrayerTimes(
    key: '15-11-2026',
    timings: const {PrayerName.fajr: '04:50'},
    date: Date(
      month: '',
      weekDay: '',
      day: '5',
      year: '1448',
      enMonth: '',
      enWeekDay: '',
      gregorianDate: '15-11-2026',
    ),
  );

  setUpAll(() => registerFallbackValue(const GetCachedPrayerDaysParams()));
  setUp(() => getDays = _MockGetDays());

  blocTest<TodayPrayerTimesCubit, PrayerTimes?>(
    'load reads one cached day',
    setUp: () => when(() => getDays(any())).thenAnswer((_) async => [today]),
    build: () => TodayPrayerTimesCubit(getDays),
    act: (c) => c.load(),
    expect: () => [today],
    verify: (_) {
      final p =
          verify(() => getDays(captureAny())).captured.single
              as GetCachedPrayerDaysParams;
      expect(p.maxDays, 1);
    },
  );

  blocTest<TodayPrayerTimesCubit, PrayerTimes?>(
    'an empty cache stays null',
    setUp: () => when(() => getDays(any())).thenAnswer((_) async => []),
    build: () => TodayPrayerTimesCubit(getDays),
    act: (c) => c.load(),
    expect: () => [],
  );
}
