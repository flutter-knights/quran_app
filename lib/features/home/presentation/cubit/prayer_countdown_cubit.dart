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

    // After-Isha refresh: same gregorian day, current prayer is Isha.
    if (currentPrayer == PrayerName.isha &&
        now.day == contextDate.day &&
        now.month == contextDate.month &&
        now.year == contextDate.year &&
        !_isAfterIshaRefreshed) {
      _isAfterIshaRefreshed = true;
      emit(PrayerCountdownRequestRefresh(silent: true));
      return;
    }

    // Midnight refresh: device clock has rolled into a new gregorian day.
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
