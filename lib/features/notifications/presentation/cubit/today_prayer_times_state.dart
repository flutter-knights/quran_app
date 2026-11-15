import 'package:equatable/equatable.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';

sealed class TodayPrayerTimesState extends Equatable {
  const TodayPrayerTimesState();

  PrayerTimes? get times => null;

  @override
  List<Object?> get props => const [];
}

final class TodayPrayerTimesLoading extends TodayPrayerTimesState {
  const TodayPrayerTimesLoading();
}

final class TodayPrayerTimesLoaded extends TodayPrayerTimesState {
  const TodayPrayerTimesLoaded(this.times);

  @override
  final PrayerTimes times;

  @override
  List<Object?> get props => [times];
}

final class TodayPrayerTimesEmpty extends TodayPrayerTimesState {
  const TodayPrayerTimesEmpty();
}
