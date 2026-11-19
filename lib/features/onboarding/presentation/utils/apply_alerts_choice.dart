import 'package:equatable/equatable.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class AlertsChoice extends Equatable {
  const AlertsChoice({
    this.sound,
    this.reminderMinutes,
    this.ringInSilent = false,
    this.stripPinned = false,
  });

  final PrayerSound? sound;
  final int? reminderMinutes;
  final bool ringInSilent;
  final bool stripPinned;

  AlertsChoice copyWith({bool? ringInSilent, bool? stripPinned}) =>
      AlertsChoice(
        sound: sound,
        reminderMinutes: reminderMinutes,
        ringInSilent: ringInSilent ?? this.ringInSilent,
        stripPinned: stripPinned ?? this.stripPinned,
      );

  @override
  List<Object?> get props => [
    sound,
    reminderMinutes,
    ringInSilent,
    stripPinned,
  ];
}

void applyAlertsChoice(SettingsCubit cubit, AlertsChoice choice) {
  cubit.updatePrayerStripPinned(choice.stripPinned);
  final sound = choice.sound;
  if (sound == null) {
    cubit.applyAlertToAll(enabled: false);
    return;
  }
  cubit.applyAlertToAll(
    enabled: true,
    sound: sound,
    ringInSilent: choice.ringInSilent && sound == PrayerSound.adhan,
    reminderEnabled: choice.reminderMinutes != null,
    reminderMinutes: choice.reminderMinutes,
  );
}

AlertsChoice alertsChoiceFrom(
  Map<PrayerName, PrayerAlert> alerts, {
  bool stripPinned = false,
}) {
  for (final p in alertPrayers) {
    final alert = alerts[p];
    if (alert != null && alert.enabled) {
      return AlertsChoice(
        sound: alert.sound,
        reminderMinutes: alert.effectiveReminderMinutes,
        ringInSilent: alert.ringInSilent,
        stripPinned: stripPinned,
      );
    }
  }
  return AlertsChoice(stripPinned: stripPinned);
}
