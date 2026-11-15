import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_cached_prayer_days.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_state.dart';

class TodayPrayerTimesCubit extends Cubit<TodayPrayerTimesState> {
  TodayPrayerTimesCubit(this._getCachedPrayerDays)
    : super(const TodayPrayerTimesLoading());

  final GetCachedPrayerDays _getCachedPrayerDays;

  Future<void> load() async {
    final days = await _getCachedPrayerDays(
      const GetCachedPrayerDaysParams(maxDays: 1),
    );
    if (isClosed) return;
    emit(
      days.isEmpty
          ? const TodayPrayerTimesEmpty()
          : TodayPrayerTimesLoaded(days.first),
    );
  }
}
