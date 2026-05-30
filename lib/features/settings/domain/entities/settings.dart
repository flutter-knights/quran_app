import 'package:equatable/equatable.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import '../../../quran_playback/domain/entities/reciter.dart';

class Settings extends Equatable {
  final bool isFormat12Hours;
  final bool isArabic;
  final ColorPalette palette;
  final MushafPaper mushafPaper;
  final double playbackSpeed;
  final Reciter defaultReciter;
  final bool isPrayerStripPinned;
  final Map<PrayerName, bool> adhanEnabledByPrayer;
  final Map<PrayerName, int> reminderMinutesByPrayer;

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

  /// The prayer-times calculation method. Defaults to [CalculationMethod.auto]
  /// which resolves the method from the user's country at runtime.
  final CalculationMethod calculationMethod;

  /// The Asr juristic school. Defaults to [AsrSchool.shafi].
  final AsrSchool asrSchool;

  static const Map<PrayerName, bool> defaultAdhanEnabled = {
    PrayerName.fajr: true,
    PrayerName.dhuhr: true,
    PrayerName.asr: true,
    PrayerName.maghrib: true,
    PrayerName.isha: true,
  };

  static const Map<PrayerName, int> defaultReminderMinutes = {
    PrayerName.fajr: 0,
    PrayerName.dhuhr: 0,
    PrayerName.asr: 0,
    PrayerName.maghrib: 0,
    PrayerName.isha: 0,
  };

  static const List<int> validReminderMinutes = [0, 5, 10, 15];

  const Settings({
    required this.isFormat12Hours,
    required this.isArabic,
    this.palette = ColorPalette.neutralDark,
    this.mushafPaper = MushafPaper.defaultPaper,
    this.playbackSpeed = 1.0,
    this.defaultReciter = Reciter.alafasy,
    this.isPrayerStripPinned = false,
    this.adhanEnabledByPrayer = defaultAdhanEnabled,
    this.reminderMinutesByPrayer = defaultReminderMinutes,
    this.hasCompletedOnboarding = false,
    this.showSplashOnLaunch = true,
    this.notificationHintDismissed = false,
    this.calculationMethod = CalculationMethod.auto,
    this.asrSchool = AsrSchool.shafi,
  });

  Settings copyWith({
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
    bool? notificationHintDismissed,
    CalculationMethod? calculationMethod,
    AsrSchool? asrSchool,
  }) {
    return Settings(
      isArabic: isArabic ?? this.isArabic,
      isFormat12Hours: isFormat12Hours ?? this.isFormat12Hours,
      palette: palette ?? this.palette,
      mushafPaper: mushafPaper ?? this.mushafPaper,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      defaultReciter: defaultReciter ?? this.defaultReciter,
      isPrayerStripPinned: isPrayerStripPinned ?? this.isPrayerStripPinned,
      adhanEnabledByPrayer: adhanEnabledByPrayer ?? this.adhanEnabledByPrayer,
      reminderMinutesByPrayer: reminderMinutesByPrayer ?? this.reminderMinutesByPrayer,
      hasCompletedOnboarding: hasCompletedOnboarding ?? this.hasCompletedOnboarding,
      showSplashOnLaunch: showSplashOnLaunch ?? this.showSplashOnLaunch,
      notificationHintDismissed: notificationHintDismissed ?? this.notificationHintDismissed,
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
        playbackSpeed,
        defaultReciter,
        isPrayerStripPinned,
        adhanEnabledByPrayer,
        reminderMinutesByPrayer,
        hasCompletedOnboarding,
        showSplashOnLaunch,
        notificationHintDismissed,
        calculationMethod,
        asrSchool,
      ];
}
