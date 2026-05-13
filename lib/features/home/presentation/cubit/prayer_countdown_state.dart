part of 'prayer_countdown_cubit.dart';

abstract class PrayerCountdownState extends Equatable {
  @override
  List<Object> get props => [];
}

class PrayerCountdownInitial extends PrayerCountdownState {}

class PrayerCountdownTick extends PrayerCountdownState {
  final PrayerCountdown prayerCountdown;
  PrayerCountdownTick(this.prayerCountdown);
  @override
  List<Object> get props => [prayerCountdown];
}

class PrayerCountdownRequestRefresh extends PrayerCountdownState {
  final bool silent;
  PrayerCountdownRequestRefresh({this.silent = true});
  @override
  List<Object> get props => [silent];
}
