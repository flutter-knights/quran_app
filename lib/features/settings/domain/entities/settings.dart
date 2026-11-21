import 'package:equatable/equatable.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import '../../../quran_playback/domain/entities/reciter.dart';

class Settings extends Equatable {
  final bool isFormat12Hours;
  final bool isArabic;
  final ColorPalette palette;
  final MushafPaper mushafPaper;
  final double pageBrightness;
  final MushafReadingMode readingMode;
  final double playbackSpeed;
  final Reciter defaultReciter;
  final bool isPrayerStripPinned;
  final Map<PrayerName, PrayerAlert> prayerAlerts;
  final StripStyle stripStyle;
  final bool alertsIntroSeen;
  final bool xiaomiAutostartConfirmed;
  final bool xiaomiBatteryConfirmed;

  /// Whether the first-run onboarding (landing page) has been completed.
  /// Defaults to `false` for brand-new installs so they see the landing; the
  /// model's `fromMap` deliberately defaults it to `true` instead, so existing
  /// users upgrading into this feature are not re-onboarded.
  final bool hasCompletedOnboarding;

  /// Whether the splash screen plays on launch. User-toggleable in settings.
  final bool showSplashOnLaunch;

  /// Whether the user dismissed the Home "turn on notifications" hint. Once
  /// dismissed it stays hidden (no re-nag); the Settings banner remains.
  final bool notificationHintDismissed;
  final bool downloadHintSeen;

  /// The prayer-times calculation method. Defaults to [CalculationMethod.auto]
  /// which resolves the method from the user's country at runtime.
  final CalculationMethod calculationMethod;

  /// The Asr juristic school. Defaults to [AsrSchool.shafi].
  final AsrSchool asrSchool;

  static const Map<PrayerName, PrayerAlert> defaultPrayerAlerts = {
    PrayerName.fajr: PrayerAlert(),
    PrayerName.dhuhr: PrayerAlert(),
    PrayerName.asr: PrayerAlert(),
    PrayerName.maghrib: PrayerAlert(),
    PrayerName.isha: PrayerAlert(),
  };

  static const double minPageBrightness = 0.3;

  /// Clearer alias for the misnamed [isFormat12Hours] field: it is `true` when
  /// the user has the **24-hour** format enabled. Use this at call sites so the
  /// inverted name stops being a bug-trap. Persisted field name is unchanged.
  bool get is24HourFormat => isFormat12Hours;

  int get enabledAlertCount =>
      prayerAlerts.values.where((a) => a.enabled).length;

  bool get usesNotifications => enabledAlertCount > 0 || isPrayerStripPinned;

  const Settings({
    required this.isFormat12Hours,
    required this.isArabic,
    this.palette = ColorPalette.neutralDark,
    this.mushafPaper = MushafPaper.cream,
    this.pageBrightness = 1.0,
    this.readingMode = MushafReadingMode.page,
    this.playbackSpeed = 1.0,
    this.defaultReciter = Reciter.alafasy,
    this.isPrayerStripPinned = false,
    this.prayerAlerts = defaultPrayerAlerts,
    this.stripStyle = const StripStyle(),
    this.alertsIntroSeen = false,
    this.xiaomiAutostartConfirmed = false,
    this.xiaomiBatteryConfirmed = false,
    this.hasCompletedOnboarding = false,
    this.showSplashOnLaunch = true,
    this.notificationHintDismissed = false,
    this.downloadHintSeen = false,
    this.calculationMethod = CalculationMethod.auto,
    this.asrSchool = AsrSchool.shafi,
  });

  Settings copyWith({
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
    bool? downloadHintSeen,
    CalculationMethod? calculationMethod,
    AsrSchool? asrSchool,
  }) {
    return Settings(
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
      downloadHintSeen: downloadHintSeen ?? this.downloadHintSeen,
      calculationMethod: calculationMethod ?? this.calculationMethod,
      asrSchool: asrSchool ?? this.asrSchool,
    );
  }

  @override
  List<Object?> get props => [
    isArabic,
    isFormat12Hours,
    palette,
    mushafPaper,
    pageBrightness,
    readingMode,
    playbackSpeed,
    defaultReciter,
    isPrayerStripPinned,
    prayerAlerts,
    stripStyle,
    alertsIntroSeen,
    xiaomiAutostartConfirmed,
    xiaomiBatteryConfirmed,
    hasCompletedOnboarding,
    showSplashOnLaunch,
    notificationHintDismissed,
    downloadHintSeen,
    calculationMethod,
    asrSchool,
  ];
}
