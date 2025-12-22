part of 'prayer_countdown_cubit.dart';

sealed class PrayerCountdownState extends Equatable {
  const PrayerCountdownState();

  @override
  List<Object> get props => [];
}

final class PrayerCountdownInitial extends PrayerCountdownState {}

final class PrayerCountdownTick extends PrayerCountdownState {
  final PrayerCountdown prayerCountdown;
  const PrayerCountdownTick(this.prayerCountdown);
  @override
  List<Object> get props => [prayerCountdown];
}
