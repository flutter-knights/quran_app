import 'package:collection/collection.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

class SettingsModel extends Settings {
  const SettingsModel({
    required super.isFormat12Hours,
    required super.isArabic,
    super.palette,
    super.mushafPaper,
    super.playbackSpeed,
    super.defaultReciter,
    super.isPrayerStripPinned,
    super.adhanEnabledByPrayer,
    super.reminderMinutesByPrayer,
    super.hasCompletedOnboarding,
    super.showSplashOnLaunch,
  });

  @override
  SettingsModel copyWith({
    bool? isFormat12Hours,
    bool? isArabic,
    ColorPalette? palette,
    MushafPaper? mushafPaper,
    double? playbackSpeed,
    Reciter? defaultReciter,
    bool? isPrayerStripPinned,
    Map<PrayerName, bool>? adhanEnabledByPrayer,
    Map<PrayerName, int>? reminderMinutesByPrayer,
    bool? hasCompletedOnboarding,
    bool? showSplashOnLaunch,
  }) {
    return SettingsModel(
      isArabic: isArabic ?? this.isArabic,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      palette: palette ?? this.palette,
      mushafPaper: mushafPaper ?? this.mushafPaper,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
      isPrayerStripPinned: isPrayerStripPinned ?? this.isPrayerStripPinned,
      adhanEnabledByPrayer: adhanEnabledByPrayer ?? this.adhanEnabledByPrayer,
      reminderMinutesByPrayer: reminderMinutesByPrayer ?? this.reminderMinutesByPrayer,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      showSplashOnLaunch: showSplashOnLaunch ?? this.showSplashOnLaunch,
    );
  }

  factory SettingsModel.fromMap(Map<String, dynamic> map) {
    return SettingsModel(
      isArabic: map['isArabic'] ?? true,
      // Inverted flag — default to 12-hour (false) when absent.
      isFormat12Hours: map['isFormat12Hours'] ?? false,
      palette: ColorPalette.values.firstWhere(
        (p) => p.name == (map['palette'] as String?),
        orElse: () => ColorPalette.neutralDark,
      ),
      mushafPaper: MushafPaper.values.firstWhere(
        (p) => p.name == (map['mushafPaper'] as String?),
        orElse: () => MushafPaper.defaultPaper,
      ),
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      defaultReciter: Reciter.values.firstWhere(
        (r) => r.name == (map['defaultReciter'] as String?),
        orElse: () => Reciter.alafasy,
      ),
      isPrayerStripPinned: map['isPrayerStripPinned'] ?? false,
      adhanEnabledByPrayer: _readEnabledMap(map['adhanEnabledByPrayer']),
      reminderMinutesByPrayer: _readReminderMap(map['reminderMinutesByPrayer']),
      // Diverges from the constructor default (false): a persisted entry that
      // predates this key belongs to an existing user who must NOT be sent
      // back through onboarding, so absence reads as "already onboarded".
      hasCompletedOnboarding: map['hasCompletedOnboarding'] ?? true,
      showSplashOnLaunch: map['showSplashOnLaunch'] ?? true,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isArabic': isArabic,
      'isFormat12Hours': isFormat12Hours,
      'palette': palette.name,
      'mushafPaper': mushafPaper.name,
      'playbackSpeed': playbackSpeed,
      'defaultReciter': defaultReciter.name,
      'isPrayerStripPinned': isPrayerStripPinned,
      'adhanEnabledByPrayer': {
        for (final e in adhanEnabledByPrayer.entries) e.key.name: e.value,
      },
      'reminderMinutesByPrayer': {
        for (final e in reminderMinutesByPrayer.entries) e.key.name: e.value,
      },
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'showSplashOnLaunch': showSplashOnLaunch,
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
