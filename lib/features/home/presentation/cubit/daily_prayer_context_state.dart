part of 'daily_prayer_context_cubit.dart';

sealed class DailyPrayerContextState extends Equatable {
  const DailyPrayerContextState();

  @override
  List<Object> get props => [];
}

final class DailyPrayerContextInitial extends DailyPrayerContextState {}

final class DailyPrayerContextLoaded extends DailyPrayerContextState {
  final DailyPrayerContext dailyPrayerContext;

  const DailyPrayerContextLoaded(this.dailyPrayerContext);
  @override
  List<Object> get props => [dailyPrayerContext];
}

final class DailyPrayerContextLoading extends DailyPrayerContextState {}

final class DailyPrayerContextFailed extends DailyPrayerContextState {
  final String error;
  const DailyPrayerContextFailed(this.error);
  @override
  List<Object> get props => [error];
}
