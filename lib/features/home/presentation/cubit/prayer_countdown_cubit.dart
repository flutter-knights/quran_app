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

  void startTimer(DailyPrayerContext dailyPrayerContext) {
    _dailyPrayerContext = dailyPrayerContext;

    _timer?.cancel();

    _emitTick();

    _timer = Timer.periodic(1.seconds, (_) => _emitTick());
  }

  void _emitTick() {
    DateTime now = DateTime.now();
    DateTime fajrTime = _dailyPrayerContext
        .prayerTimes
        .timings[PrayerName.fajr]!
        .parse24hTime()
        .add(1.days);

    Duration remainingTime = fajrTime.difference(now);
    PrayerName currentPrayer = PrayerName.isha;
    PrayerName nextPrayer = PrayerName.fajr;

    for (PrayerName prayerName in prayersList) {
      DateTime prayerTime = _dailyPrayerContext.prayerTimes.timings[prayerName]!
          .parse24hTime();

      if (now.isAfter(prayerTime)) {
        currentPrayer = prayerName;
        continue;
      }
      if (now.isBefore(prayerTime)) {
        remainingTime = prayerTime.difference(now);
        nextPrayer = prayerName;
        break;
      }
    }

    emit(
      PrayerCountdownTick(
        PrayerCountdown(
          currentPrayer: currentPrayer,
          nextPrayer: nextPrayer,
          remainingTime: remainingTime,
        ),
      ),
    );
  }

  @override
  Future<void> close() {
    _timer?.cancel();
    return super.close();
  }
}
