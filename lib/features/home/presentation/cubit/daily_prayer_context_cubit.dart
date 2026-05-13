import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';
import 'package:quran_app/features/home/domain/usecases/get_daily_prayer_context.dart';

part 'daily_prayer_context_state.dart';

class DailyPrayerContextCubit extends Cubit<DailyPrayerContextState> {
  DailyPrayerContextCubit({required this.getDailyPrayerContext})
      : super(DailyPrayerContextInitial());

  final GetDailyPrayerContext getDailyPrayerContext;

  /// [silent]: when true, suppresses [DailyPrayerContextLoading].
  /// Used by after-Isha and midnight auto-refreshes to avoid a UI flash.
  Future<void> fetchDailyPrayerContext({bool silent = false}) async {
    if (!silent) emit(DailyPrayerContextLoading());

    await getDailyPrayerContext(NoParams()).forEach((result) {
      if (isClosed) return;
      result.fold(
        (failure) => emit(DailyPrayerContextFailed(failure.message)),
        (dailyPrayerContext) =>
            emit(DailyPrayerContextLoaded(dailyPrayerContext)),
      );
    });
  }
}
