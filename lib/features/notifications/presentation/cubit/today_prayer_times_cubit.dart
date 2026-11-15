import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_cached_prayer_days.dart';

class TodayPrayerTimesCubit extends Cubit<PrayerTimes?> {
  TodayPrayerTimesCubit(this._getCachedPrayerDays) : super(null);

  final GetCachedPrayerDays _getCachedPrayerDays;

  Future<void> load() async {
    final days = await _getCachedPrayerDays(
      const GetCachedPrayerDaysParams(maxDays: 1),
    );
    if (isClosed || days.isEmpty) return;
    emit(days.first);
  }
}
