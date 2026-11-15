import 'package:collection/collection.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

class SettingsModel extends Settings {
  const SettingsModel({
    required super.isFormat12Hours,
    required super.isArabic,
    super.palette,
    super.mushafPaper,
    super.pageBrightness,
    super.readingMode,
    super.playbackSpeed,
    super.defaultReciter,
    super.isPrayerStripPinned,
    super.prayerAlerts,
    super.stripStyle,
    super.alertsIntroSeen,
    super.xiaomiAutostartConfirmed,
    super.xiaomiBatteryConfirmed,
    super.hasCompletedOnboarding,
    super.showSplashOnLaunch,
    super.notificationHintDismissed,
    super.calculationMethod,
    super.asrSchool,
  });

  @override
  SettingsModel copyWith({
    bool? isFormat12Hours,
    bool? isArabic,
    ColorPalette? palette,
    MushafPaper? mushafPaper,
    double? pageBrightness,
    MushafReadingMode? readingMode,
    double? playbackSpeed,
    Reciter? defaultReciter,
    bool? isPrayerStripPinned,
    Map<PrayerName, PrayerAlert>? prayerAlerts,
    StripStyle? stripStyle,
    bool? alertsIntroSeen,
    bool? xiaomiAutostartConfirmed,
    bool? xiaomiBatteryConfirmed,
    bool? hasCompletedOnboarding,
    bool? showSplashOnLaunch,
    bool? notificationHintDismissed,
    CalculationMethod? calculationMethod,
    AsrSchool? asrSchool,
  }) {
    return SettingsModel(
      isArabic: isArabic ?? this.isArabic,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      palette: palette ?? this.palette,
      mushafPaper: mushafPaper ?? this.mushafPaper,
      pageBrightness: pageBrightness ?? this.pageBrightness,
      readingMode: readingMode ?? this.readingMode,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
      isPrayerStripPinned: isPrayerStripPinned ?? this.isPrayerStripPinned,
      prayerAlerts: prayerAlerts ?? this.prayerAlerts,
      stripStyle: stripStyle ?? this.stripStyle,
      alertsIntroSeen: alertsIntroSeen ?? this.alertsIntroSeen,
      xiaomiAutostartConfirmed:
          xiaomiAutostartConfirmed ?? this.xiaomiAutostartConfirmed,
      xiaomiBatteryConfirmed:
          xiaomiBatteryConfirmed ?? this.xiaomiBatteryConfirmed,
      hasCompletedOnboarding:
          hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      showSplashOnLaunch: showSplashOnLaunch ?? this.showSplashOnLaunch,
      notificationHintDismissed:
          notificationHintDismissed ?? this.notificationHintDismissed,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      asrSchool: asrSchool ?? this.asrSchool,
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
        orElse: () => MushafPaper.cream,
      ),
      pageBrightness: _readBrightness(map['pageBrightness']),
      readingMode: MushafReadingMode.values.firstWhere(
        (m) => m.name == (map['readingMode'] as String?),
        orElse: () => MushafReadingMode.page,
      ),
      playbackSpeed: (map['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
      defaultReciter: Reciter.values.firstWhere(
        (r) => r.name == (map['defaultReciter'] as String?),
        orElse: () => Reciter.alafasy,
      ),
      isPrayerStripPinned: map['isPrayerStripPinned'] ?? false,
      prayerAlerts: _readPrayerAlerts(map),
      stripStyle: _readStripStyle(map['stripStyle']),
      alertsIntroSeen: _readBool(map['alertsIntroSeen']),
      xiaomiAutostartConfirmed: _readBool(map['xiaomiAutostartConfirmed']),
      xiaomiBatteryConfirmed: _readBool(map['xiaomiBatteryConfirmed']),
      // Diverges from the constructor default (false): a persisted entry that
      // predates this key belongs to an existing user who must NOT be sent
      // back through onboarding, so absence reads as "already onboarded".
      hasCompletedOnboarding: map['hasCompletedOnboarding'] ?? true,
      showSplashOnLaunch: map['showSplashOnLaunch'] ?? true,
      notificationHintDismissed: map['notificationHintDismissed'] ?? false,
      calculationMethod: CalculationMethod.values.firstWhere(
        (m) => m.name == (map['calculationMethod'] as String?),
        orElse: () => CalculationMethod.auto,
      ),
      asrSchool: AsrSchool.values.firstWhere(
        (sch) => sch.name == (map['asrSchool'] as String?),
        orElse: () => AsrSchool.shafi,
      ),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'isArabic': isArabic,
      'isFormat12Hours': isFormat12Hours,
      'palette': palette.name,
      'mushafPaper': mushafPaper.name,
      'pageBrightness': pageBrightness,
      'readingMode': readingMode.name,
      'playbackSpeed': playbackSpeed,
      'defaultReciter': defaultReciter.name,
      'isPrayerStripPinned': isPrayerStripPinned,
      'prayerAlerts': {
        for (final e in prayerAlerts.entries)
          e.key.name: {
            'enabled': e.value.enabled,
            'sound': e.value.sound.name,
            'ringInSilent': e.value.ringInSilent,
            'reminderEnabled': e.value.reminderEnabled,
            'reminderMinutes': e.value.reminderMinutes,
            'reminderSound': e.value.reminderSound.name,
          },
      },
      'stripStyle': {
        'expanded': stripStyle.expanded,
        'showCountdown': stripStyle.showCountdown,
        'highlight': stripStyle.highlight.name,
        'background': stripStyle.background.name,
        'shape': stripStyle.shape.name,
      },
      'alertsIntroSeen': alertsIntroSeen,
      'xiaomiAutostartConfirmed': xiaomiAutostartConfirmed,
      'xiaomiBatteryConfirmed': xiaomiBatteryConfirmed,
      'hasCompletedOnboarding': hasCompletedOnboarding,
      'showSplashOnLaunch': showSplashOnLaunch,
      'notificationHintDismissed': notificationHintDismissed,
      'calculationMethod': calculationMethod.name,
      'asrSchool': asrSchool.name,
    };
  }

  static double _readBrightness(dynamic raw) {
    final v = (raw as num?)?.toDouble();
    if (v == null) return 1.0;
    return v.clamp(Settings.minPageBrightness, 1.0);
  }

  static bool _readBool(Object? raw, [bool fallback = false]) =>
      raw is bool ? raw : fallback;

  static int _clampReminder(int minutes) => minutes.clamp(
    PrayerAlert.minReminderMinutes,
    PrayerAlert.maxReminderMinutes,
  );

  static T _readEnum<T extends Enum>(List<T> values, Object? raw, T fallback) =>
      values.firstWhereOrNull((e) => e.name == raw) ?? fallback;

  static Map<PrayerName, PrayerAlert> _readPrayerAlerts(
    Map<String, dynamic> map,
  ) {
    final raw = map['prayerAlerts'];
    if (raw is Map) {
      return {for (final p in alertPrayers) p: _alertFromMap(raw[p.name])};
    }
    final enabled = map['adhanEnabledByPrayer'];
    final minutes = map['reminderMinutesByPrayer'];
    return {
      for (final p in alertPrayers)
        p: _migrateLegacy(
          enabled is Map ? enabled[p.name] : null,
          minutes is Map ? minutes[p.name] : null,
        ),
    };
  }

  static PrayerAlert _migrateLegacy(Object? enabled, Object? minutes) {
    final m = minutes is int ? minutes : 0;
    return PrayerAlert(
      enabled: _readBool(enabled, true),
      reminderEnabled: m > 0,
      reminderMinutes: m > 0 ? _clampReminder(m) : 10,
    );
  }

  static PrayerAlert _alertFromMap(Object? raw) {
    const d = PrayerAlert();
    if (raw is! Map) return d;
    final minutes = raw['reminderMinutes'];
    return PrayerAlert(
      enabled: _readBool(raw['enabled'], d.enabled),
      sound: _readEnum(PrayerSound.values, raw['sound'], d.sound),
      ringInSilent: _readBool(raw['ringInSilent'], d.ringInSilent),
      reminderEnabled: _readBool(raw['reminderEnabled'], d.reminderEnabled),
      reminderMinutes: minutes is int
          ? _clampReminder(minutes)
          : d.reminderMinutes,
      reminderSound: _readEnum(
        ReminderSound.values,
        raw['reminderSound'],
        d.reminderSound,
      ),
    );
  }

  static StripStyle _readStripStyle(Object? raw) {
    const d = StripStyle();
    if (raw is! Map) return d;
    return StripStyle(
      expanded: _readBool(raw['expanded'], d.expanded),
      showCountdown: _readBool(raw['showCountdown'], d.showCountdown),
      highlight: _readEnum(
        StripHighlight.values,
        raw['highlight'],
        d.highlight,
      ),
      background: _readEnum(
        StripBackground.values,
        raw['background'],
        d.background,
      ),
      shape: _readEnum(StripShape.values, raw['shape'], d.shape),
    );
  }
}
