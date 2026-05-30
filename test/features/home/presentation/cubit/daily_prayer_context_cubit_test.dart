import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/core/errors/failure.dart';
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
    registerFallbackValue(
      const GetDailyPrayerContextParams(
        method: CalculationMethod.auto,
        school: AsrSchool.shafi,
      ),
    );
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
    act: (c) => c.fetchDailyPrayerContext(
      method: CalculationMethod.auto,
      school: AsrSchool.shafi,
    ),
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
    act: (c) => c.fetchDailyPrayerContext(
      silent: true,
      method: CalculationMethod.auto,
      school: AsrSchool.shafi,
    ),
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
    act: (c) => c.fetchDailyPrayerContext(
      method: CalculationMethod.auto,
      school: AsrSchool.shafi,
    ),
    expect: () => [
      isA<DailyPrayerContextLoading>(),
      isA<DailyPrayerContextFailed>(),
    ],
  );

  blocTest<DailyPrayerContextCubit, DailyPrayerContextState>(
    'fetchDailyPrayerContext: Failed state carries the typed Failure',
    build: () {
      when(() => usecase.call(any())).thenAnswer(
        (_) => Stream.value(
          const Left(LocationPermissionDeniedFailure('denied')),
        ),
      );
      return DailyPrayerContextCubit(getDailyPrayerContext: usecase);
    },
    act: (c) => c.fetchDailyPrayerContext(
      method: CalculationMethod.auto,
      school: AsrSchool.shafi,
    ),
    expect: () => [
      isA<DailyPrayerContextLoading>(),
      isA<DailyPrayerContextFailed>().having(
        (s) => s.failure,
        'failure',
        isA<LocationPermissionDeniedFailure>(),
      ),
    ],
  );

  test(
    'cancel in-flight (M4): second fetch cancels first; late emission from '
    'first stream does not overwrite second result',
    () async {
      // First call: a stream we control — won't emit until we push.
      final firstController =
          StreamController<Either<Failure, DailyPrayerContext>>();

      // Second call: emits a Loaded result immediately.
      final secondCtx = ctx; // same ctx for simplicity

      var callCount = 0;
      when(() => usecase.call(any())).thenAnswer((_) {
        callCount++;
        if (callCount == 1) return firstController.stream;
        return Stream.value(Right(secondCtx));
      });

      final cubit =
          DailyPrayerContextCubit(getDailyPrayerContext: usecase);

      // Start first fetch (emits Loading, then hangs).
      unawaited(
        cubit.fetchDailyPrayerContext(
          method: CalculationMethod.auto,
          school: AsrSchool.shafi,
        ),
      );

      // Give the first fetch a moment to subscribe.
      await Future<void>.delayed(Duration.zero);

      // Start second fetch (cancels first, emits Loading then Loaded).
      await cubit.fetchDailyPrayerContext(
        method: CalculationMethod.mwl,
        school: AsrSchool.hanafi,
      );

      // Allow the second stream to deliver its Loaded event.
      await Future<void>.delayed(Duration.zero);

      // Now emit from the (cancelled) first stream — should be ignored.
      firstController.add(Right(ctx));
      await Future<void>.delayed(Duration.zero);

      // Final state must be Loaded (from the second fetch), not overwritten.
      expect(cubit.state, isA<DailyPrayerContextLoaded>());

      await firstController.close();
      await cubit.close();
    },
  );
}
