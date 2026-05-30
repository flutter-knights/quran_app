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
  final Failure failure;

  const DailyPrayerContextFailed(this.failure);

  String get message => failure.message;

  @override
  List<Object> get props => [failure];
}
