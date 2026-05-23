import 'package:equatable/equatable.dart';

import 'package:quran_app/core/constants/prayer_name.dart';
import '../../../quran_playback/domain/entities/reciter.dart';

class Settings extends Equatable {
  final bool isDarkMode;
  final bool isFormat12Hours;
  final bool isArabic;
  final double playbackSpeed;
  final Reciter defaultReciter;
  final bool isPrayerStripPinned;

  /// Keyed by the five obligatory prayers. [PrayerName.sunrise] is intentionally
  /// excluded — sunrise has no adhan in this app.
  final Map<PrayerName, bool> adhanEnabledByPrayer;

  /// Keyed by the five obligatory prayers. [PrayerName.sunrise] is intentionally
  /// excluded — sunrise has no adhan in this app.
  final Map<PrayerName, int> reminderMinutesByPrayer;

  /// Keyed by the five obligatory prayers. [PrayerName.sunrise] is intentionally
  /// excluded — sunrise has no adhan in this app.
  static const Map<PrayerName, bool> defaultAdhanEnabled = {
    PrayerName.fajr: true,
    PrayerName.dhuhr: true,
    PrayerName.asr: true,
    PrayerName.maghrib: true,
    PrayerName.isha: true,
  };

  /// Keyed by the five obligatory prayers. [PrayerName.sunrise] is intentionally
  /// excluded — sunrise has no adhan in this app.
  static const Map<PrayerName, int> defaultReminderMinutes = {
    PrayerName.fajr: 0,
    PrayerName.dhuhr: 0,
    PrayerName.asr: 0,
    PrayerName.maghrib: 0,
    PrayerName.isha: 0,
  };

  static const List<int> validReminderMinutes = [0, 5, 10, 15];

  const Settings({
    required this.isDarkMode,
    required this.isFormat12Hours,
    required this.isArabic,
    this.playbackSpeed = 1.0,
    this.defaultReciter = Reciter.alafasy,
    this.isPrayerStripPinned = false,
    this.adhanEnabledByPrayer = defaultAdhanEnabled,
    this.reminderMinutesByPrayer = defaultReminderMinutes,
  });

  Settings copyWith({
    bool? isDarkMode,
    bool? isFormat12Hours,
    bool? isArabic,
    double? playbackSpeed,
    Reciter? defaultReciter,
    bool? isPrayerStripPinned,
    Map<PrayerName, bool>? adhanEnabledByPrayer,
    Map<PrayerName, int>? reminderMinutesByPrayer,
  }) {
    return Settings(
      isArabic: isArabic ?? this.isArabic,
      isDarkMode: isDarkMode ?? this.isDarkMode,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
      isPrayerStripPinned: isPrayerStripPinned ?? this.isPrayerStripPinned,
      adhanEnabledByPrayer: adhanEnabledByPrayer ?? this.adhanEnabledByPrayer,
      reminderMinutesByPrayer:
          reminderMinutesByPrayer ?? this.reminderMinutesByPrayer,
    );
  }

  @override
  List<Object?> get props => [
        isArabic,
        isDarkMode,
        isFormat12Hours,
        playbackSpeed,
        defaultReciter,
        isPrayerStripPinned,
        adhanEnabledByPrayer,
        reminderMinutesByPrayer,
      ];
}
