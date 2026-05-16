import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';

// All six prayers are placed at ishaHour:00 through ishaHour:05, ensuring
// that when ishaHour=0 (midnight) every prayer is already past at any
// normal test runtime, making currentPrayer == isha reliably.
DailyPrayerContext ctxFor(DateTime d, {int ishaHour = 19}) {
  String two(int n) => n.toString().padLeft(2, '0');
  final key = '${two(d.day)}-${two(d.month)}-${d.year}';
  return DailyPrayerContext(
    location: Location(latitude: 30, longitude: 31),
    date: key,
    prayerTimes: PrayerTimes(
      key: key,
      timings: {
        PrayerName.fajr: '${two(ishaHour)}:00',
        PrayerName.sunrise: '${two(ishaHour)}:01',
        PrayerName.dhuhr: '${two(ishaHour)}:02',
        PrayerName.asr: '${two(ishaHour)}:03',
        PrayerName.maghrib: '${two(ishaHour)}:04',
        PrayerName.isha: '${two(ishaHour)}:05',
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
    // ishaHour=0 → all prayers at 00:00-00:05, so now (daytime) is always after isha
    final ctx = ctxFor(today, ishaHour: 0);

    final emitted = <PrayerCountdownState>[];
    final sub = cubit.stream.listen(emitted.add);

    cubit.startTimer(ctx);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(emitted.whereType<PrayerCountdownTick>().isNotEmpty, isTrue);
    final refreshes =
        emitted.whereType<PrayerCountdownRequestRefresh>().toList();
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
    final ctx = ctxFor(yesterday, ishaHour: 0);

    final emitted = <PrayerCountdownState>[];
    final sub = cubit.stream.listen(emitted.add);

    cubit.startTimer(ctx);
    await Future<void>.delayed(const Duration(milliseconds: 50));

    final refreshes =
        emitted.whereType<PrayerCountdownRequestRefresh>().toList();
    expect(refreshes, hasLength(1));
    expect(refreshes.first.silent, isTrue);

    await sub.cancel();
    await cubit.close();
  });

  test(
      'new-day context after midnight resets flags so refresh fires again',
      () async {
    final cubit = PrayerCountdownCubit();
    final today = DateTime.now();

    // 1st context: today after isha — fires refresh
    cubit.startTimer(ctxFor(today, ishaHour: 0));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    // 2nd context: tomorrow (different date) — flags reset, refresh fires again
    final tomorrow = today.add(const Duration(days: 1));
    final emitted = <PrayerCountdownState>[];
    final sub = cubit.stream.listen(emitted.add);

    cubit.startTimer(ctxFor(tomorrow, ishaHour: 0));
    await Future<void>.delayed(const Duration(milliseconds: 30));

    expect(
      emitted.whereType<PrayerCountdownRequestRefresh>().length,
      greaterThanOrEqualTo(1),
      reason: 'new-day context resets flags → refresh fires again',
    );

    await sub.cancel();
    await cubit.close();
  });
}
