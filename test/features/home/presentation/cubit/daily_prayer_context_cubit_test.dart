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
        gregorianDate: '15-05-2025',
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
