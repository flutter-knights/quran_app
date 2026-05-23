import 'package:collection/collection.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

class SettingsModel extends Settings {
  const SettingsModel({
    required super.isDarkMode,
    required super.isFormat12Hours,
    required super.isArabic,
    super.playbackSpeed,
    super.defaultReciter,
    super.isPrayerStripPinned,
    super.adhanEnabledByPrayer,
    super.reminderMinutesByPrayer,
  });

  @override
  SettingsModel copyWith({
    bool? isDarkMode,
    bool? isFormat12Hours,
    bool? isArabic,
    double? playbackSpeed,
    Reciter? defaultReciter,
    bool? isPrayerStripPinned,
    Map<PrayerName, bool>? adhanEnabledByPrayer,
    Map<PrayerName, int>? reminderMinutesByPrayer,
  }) {
    return SettingsModel(
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

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      isArabic: map['isArabic'] ?? true,
      isDarkMode: map['isDarkMode'] ?? true,
      isFormat12Hours: map['isFormat12Hours'] ?? true,
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      defaultReciter: Reciter.values.firstWhere(
        (r) => r.name == (map['defaultReciter'] as String?),
        orElse: () => Reciter.alafasy,
      ),
      isPrayerStripPinned: map['isPrayerStripPinned'] ?? false,
      adhanEnabledByPrayer: _readEnabledMap(map['adhanEnabledByPrayer']),
      reminderMinutesByPrayer: _readReminderMap(map['reminderMinutesByPrayer']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isArabic': isArabic,
      'isDarkMode': isDarkMode,
      'isFormat12Hours': isFormat12Hours,
      'playbackSpeed': playbackSpeed,
      'defaultReciter': defaultReciter.name,
      'isPrayerStripPinned': isPrayerStripPinned,
      'adhanEnabledByPrayer': {
        for (final e in adhanEnabledByPrayer.entries) e.key.name: e.value,
      },
      'reminderMinutesByPrayer': {
        for (final e in reminderMinutesByPrayer.entries) e.key.name: e.value,
      },
    };
  }

  static Map<PrayerName, bool> _readEnabledMap(dynamic raw) {
    if (raw is! Map) return Settings.defaultAdhanEnabled;
    final result = <PrayerName, bool>{...Settings.defaultAdhanEnabled};
    for (final e in raw.entries) {
      if (e.key is! String) continue;
      final p = PrayerName.values.firstWhereOrNull((x) => x.name == e.key);
      final v = e.value;
      if (p != null && v is bool) result[p] = v;
    }
    return result;
  }

  static Map<PrayerName, int> _readReminderMap(dynamic raw) {
    if (raw is! Map) return Settings.defaultReminderMinutes;
    final result = <PrayerName, int>{...Settings.defaultReminderMinutes};
    for (final e in raw.entries) {
      if (e.key is! String) continue;
      final p = PrayerName.values.firstWhereOrNull((x) => x.name == e.key);
      final v = e.value;
      if (p != null && v is int && Settings.validReminderMinutes.contains(v)) {
        result[p] = v;
      }
    }
    return result;
  }
}
