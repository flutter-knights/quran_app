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

  late DailyPrayerContext _dailyPrayerContext;

  Timer? _timer;
  bool _isRefreshed = false;
  void startTimer(DailyPrayerContext dailyPrayerContext) {
    _dailyPrayerContext = dailyPrayerContext;

    _timer?.cancel();

    _emitTick();

    _timer = Timer.periodic(1.seconds, (_) => _emitTick());
  }

  void _emitTick() {
    DateTime now = DateTime.now();

    PrayerName currentPrayer = PrayerName.isha;
    PrayerName nextPrayer = PrayerName.fajr;

    DateTime targetNextPrayerTime = _dailyPrayerContext
        .prayerTimes
        .timings[PrayerName.fajr]!
        .parse24hTime(date: _dailyPrayerContext.date.gregorianDate())
        .add(1.days);

    for (PrayerName prayerName in prayersList) {
      DateTime prayerTime = _dailyPrayerContext.prayerTimes.timings[prayerName]!
          .parse24hTime(date: _dailyPrayerContext.date.gregorianDate());

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
    if (currentPrayer == PrayerName.isha &&
        now.day == _dailyPrayerContext.date.gregorianDate().day &&
        !_isRefreshed) {
      _isRefreshed = true;
      emit(PrayerCountdownRequestRefresh());
    }
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
