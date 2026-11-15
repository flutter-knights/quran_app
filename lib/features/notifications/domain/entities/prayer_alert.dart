import 'package:equatable/equatable.dart';
import 'package:quran_app/core/constants/prayer_name.dart';

enum PrayerSound { adhan, tone, vibrate, silent }

enum ReminderSound { tone, vibrate, silent }

const alertPrayers = [
  PrayerName.fajr,
  PrayerName.dhuhr,
  PrayerName.asr,
  PrayerName.maghrib,
  PrayerName.isha,
];

class PrayerAlert extends Equatable {
  static const minReminderMinutes = 1;
  static const maxReminderMinutes = 60;

  final bool enabled;
  final PrayerSound sound;
  final bool ringInSilent;
  final bool reminderEnabled;
  final int reminderMinutes;
  final ReminderSound reminderSound;

  const PrayerAlert({
    this.enabled = true,
    this.sound = PrayerSound.adhan,
    this.ringInSilent = false,
    this.reminderEnabled = false,
    this.reminderMinutes = 10,
    this.reminderSound = ReminderSound.tone,
  });

  int? get effectiveReminderMinutes =>
      enabled && reminderEnabled ? reminderMinutes : null;

  PrayerAlert copyWith({
    bool? enabled,
    PrayerSound? sound,
    bool? ringInSilent,
    bool? reminderEnabled,
    int? reminderMinutes,
    ReminderSound? reminderSound,
  }) {
    return PrayerAlert(
      enabled: enabled ?? this.enabled,
      sound: sound ?? this.sound,
      ringInSilent: ringInSilent ?? this.ringInSilent,
      reminderEnabled: reminderEnabled ?? this.reminderEnabled,
      reminderMinutes: reminderMinutes ?? this.reminderMinutes,
      reminderSound: reminderSound ?? this.reminderSound,
    );
  }

  @override
  List<Object?> get props => [
    enabled,
    sound,
    ringInSilent,
    reminderEnabled,
    reminderMinutes,
    reminderSound,
  ];
}
