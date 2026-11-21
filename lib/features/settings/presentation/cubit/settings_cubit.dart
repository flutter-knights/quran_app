import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

part 'settings_state.dart';

class SettingsCubit extends HydratedCubit<SettingsState> {
  static const defaultPalette = ColorPalette.neutralDark;

  SettingsCubit()
    : super(
        SettingsState(
          SettingsModel(
            palette: defaultPalette,
            // NOTE: this flag is inverted — `false` selects the 12-hour
            // format, `true` selects 24-hour. Default first run to 12-hour.
            isFormat12Hours: false,
            isArabic: true,
          ),
        ),
      );

  void updateSettings({bool? isFormat12Hours, bool? isArabic}) {
    emit(
      SettingsState(
        state.settingsModel.copyWith(
          isFormat12Hours: isFormat12Hours,
          isArabic: isArabic,
        ),
      ),
    );
  }

  void updatePalette(ColorPalette palette) {
    emit(SettingsState(state.settingsModel.copyWith(palette: palette)));
  }

  void updateMushafPaper(MushafPaper paper) {
    emit(SettingsState(state.settingsModel.copyWith(mushafPaper: paper)));
  }

  void updatePageBrightness(double value) {
    final clamped = value.clamp(Settings.minPageBrightness, 1.0);
    emit(SettingsState(state.settingsModel.copyWith(pageBrightness: clamped)));
  }

  void updateReadingMode(MushafReadingMode mode) {
    emit(SettingsState(state.settingsModel.copyWith(readingMode: mode)));
  }

  void updatePlaybackSpeed(double speed) {
    emit(SettingsState(state.settingsModel.copyWith(playbackSpeed: speed)));
  }

  void updateDefaultReciter(Reciter reciter) {
    emit(SettingsState(state.settingsModel.copyWith(defaultReciter: reciter)));
  }

  void updatePrayerStripPinned(bool value) {
    emit(
      SettingsState(state.settingsModel.copyWith(isPrayerStripPinned: value)),
    );
  }

  /// Marks first-run onboarding (the landing page) as completed, so the landing
  /// is never shown again on subsequent launches.
  void completeOnboarding() {
    final s = state.settingsModel;
    if (s.hasCompletedOnboarding && s.alertsIntroSeen) return;
    emit(
      SettingsState(
        s.copyWith(hasCompletedOnboarding: true, alertsIntroSeen: true),
      ),
    );
  }

  /// Permanently dismisses the Home notification hint.
  void dismissNotificationHint() {
    if (state.settingsModel.notificationHintDismissed) return;
    emit(
      SettingsState(
        state.settingsModel.copyWith(notificationHintDismissed: true),
      ),
    );
  }

  void markDownloadHintSeen() {
    if (state.settingsModel.downloadHintSeen) return;
    emit(SettingsState(state.settingsModel.copyWith(downloadHintSeen: true)));
  }

  void updateShowSplashOnLaunch(bool value) {
    emit(
      SettingsState(state.settingsModel.copyWith(showSplashOnLaunch: value)),
    );
  }

  void updateCalculationMethod(CalculationMethod method) {
    emit(
      SettingsState(state.settingsModel.copyWith(calculationMethod: method)),
    );
  }

  void updateAsrSchool(AsrSchool school) {
    emit(SettingsState(state.settingsModel.copyWith(asrSchool: school)));
  }

  void updatePrayerAlert(PrayerName prayer, PrayerAlert alert) {
    final next = {...state.settingsModel.prayerAlerts, prayer: _clamped(alert)};
    emit(SettingsState(state.settingsModel.copyWith(prayerAlerts: next)));
  }

  void applyAlertToAll({
    required bool enabled,
    PrayerSound? sound,
    bool? ringInSilent,
    bool? reminderEnabled,
    int? reminderMinutes,
  }) {
    final current = state.settingsModel.prayerAlerts;
    final next = {
      for (final p in alertPrayers)
        p: _clamped(
          (current[p] ?? const PrayerAlert()).copyWith(
            enabled: enabled,
            sound: sound,
            ringInSilent: ringInSilent,
            reminderEnabled: reminderEnabled,
            reminderMinutes: reminderMinutes,
          ),
        ),
    };
    emit(SettingsState(state.settingsModel.copyWith(prayerAlerts: next)));
  }

  void updateStripStyle(StripStyle style) {
    emit(SettingsState(state.settingsModel.copyWith(stripStyle: style)));
  }

  void markAlertsIntroSeen() {
    if (state.settingsModel.alertsIntroSeen) return;
    emit(SettingsState(state.settingsModel.copyWith(alertsIntroSeen: true)));
  }

  void setXiaomiAutostartConfirmed(bool value) {
    emit(
      SettingsState(
        state.settingsModel.copyWith(xiaomiAutostartConfirmed: value),
      ),
    );
  }

  void setXiaomiBatteryConfirmed(bool value) {
    emit(
      SettingsState(
        state.settingsModel.copyWith(xiaomiBatteryConfirmed: value),
      ),
    );
  }

  void clearXiaomiConfirmations() {
    emit(
      SettingsState(
        state.settingsModel.copyWith(
          xiaomiAutostartConfirmed: false,
          xiaomiBatteryConfirmed: false,
        ),
      ),
    );
  }

  static PrayerAlert _clamped(PrayerAlert alert) => alert.copyWith(
    reminderMinutes: PrayerAlert.clampMinutes(alert.reminderMinutes),
  );

  @override
  SettingsState? fromJson(Map<String, dynamic> json) {
    // Never throw — a malformed persisted entry must not brick app launch.
    // Returning null falls back to the default settings instead.
    try {
      return SettingsState(SettingsModel.fromMap(json));
    } catch (_) {
      return null;
    }
  }

  @override
  Map<String, dynamic>? toJson(SettingsState state) {
    return state.settingsModel.toMap();
  }
}
