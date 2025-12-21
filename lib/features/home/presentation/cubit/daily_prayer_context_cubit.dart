import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/usecases/get_daily_prayer_context.dart';

part 'daily_prayer_context_state.dart';

class DailyPrayerContextCubit extends Cubit<DailyPrayerContextState> {
  DailyPrayerContextCubit({required this.getDailyPrayerContext})
    : super(DailyPrayerContextInitial());
  final GetDailyPrayerContext getDailyPrayerContext;

  void fetchDailyPrayerContext() async {
    emit(DailyPrayerContextLoading());
    final result = await getDailyPrayerContext(NoParams());
    result.fold(
      (failure) => emit(DailyPrayerContextFailed(failure.message)),
      (dailyPrayerContext) => emit(DailyPrayerContextLoaded()),
    );
  }
}
