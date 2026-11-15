import 'package:equatable/equatable.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class AlertsChoice extends Equatable {
  const AlertsChoice({this.sound, this.reminderMinutes});

  final PrayerSound? sound;
  final int? reminderMinutes;

  @override
  List<Object?> get props => [sound, reminderMinutes];
}

void applyAlertsChoice(SettingsCubit cubit, AlertsChoice choice) {
  final sound = choice.sound;
  if (sound == null) {
    cubit.applyAlertToAll(enabled: false);
    return;
  }
  cubit.applyAlertToAll(
    enabled: true,
    sound: sound,
    reminderEnabled: choice.reminderMinutes != null,
    reminderMinutes: choice.reminderMinutes,
  );
}
