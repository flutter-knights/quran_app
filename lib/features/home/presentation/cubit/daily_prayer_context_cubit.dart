import 'dart:async';

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';
import 'package:quran_app/features/home/domain/usecases/get_daily_prayer_context.dart';

part 'daily_prayer_context_state.dart';

class DailyPrayerContextCubit extends Cubit<DailyPrayerContextState> {
  DailyPrayerContextCubit({required this.getDailyPrayerContext})
      : super(DailyPrayerContextInitial());

  final GetDailyPrayerContext getDailyPrayerContext;

  StreamSubscription? _sub;

  /// [silent]: when true, suppresses [DailyPrayerContextLoading].
  /// Used by after-Isha and midnight auto-refreshes to avoid a UI flash.
  Future<void> fetchDailyPrayerContext({
    bool silent = false,
    required CalculationMethod method,
    required AsrSchool school,
  }) async {
    await _sub?.cancel();
    if (!silent) emit(DailyPrayerContextLoading());
    _sub = getDailyPrayerContext(
      GetDailyPrayerContextParams(method: method, school: school),
    ).listen((result) {
      if (isClosed) return;
      result.fold(
        (failure) => emit(DailyPrayerContextFailed(failure)),
        (dailyPrayerContext) =>
            emit(DailyPrayerContextLoaded(dailyPrayerContext)),
      );
    });
  }

  @override
  Future<void> close() async {
    await _sub?.cancel();
    return super.close();
  }
}
