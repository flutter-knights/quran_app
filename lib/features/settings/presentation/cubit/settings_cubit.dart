import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/color_palette.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

part 'settings_state.dart';

class SettingsCubit extends HydratedCubit<SettingsState> {
  SettingsCubit()
      : super(
          SettingsState(
            SettingsModel(
              palette: ColorPalette.neutralDark,
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
    emit(SettingsState(
      state.settingsModel.copyWith(pageBrightness: clamped),
    ));
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
    if (state.settingsModel.hasCompletedOnboarding) return;
    emit(
      SettingsState(
        state.settingsModel.copyWith(hasCompletedOnboarding: true),
      ),
    );
  }

  void updateShowSplashOnLaunch(bool value) {
    emit(
      SettingsState(state.settingsModel.copyWith(showSplashOnLaunch: value)),
    );
  }

  void updateAdhanEnabled(PrayerName prayer, bool enabled) {
    final next = Map<PrayerName, bool>.from(
      state.settingsModel.adhanEnabledByPrayer,
    )..[prayer] = enabled;
    emit(SettingsState(state.settingsModel.copyWith(adhanEnabledByPrayer: next)));
  }

  void updateReminderMinutes(PrayerName prayer, int minutes) {
    assert(
      Settings.validReminderMinutes.contains(minutes),
      'reminder minutes must be one of ${Settings.validReminderMinutes}, got $minutes',
    );
    final next = Map<PrayerName, int>.from(
      state.settingsModel.reminderMinutesByPrayer,
    )..[prayer] = minutes;
    emit(SettingsState(state.settingsModel.copyWith(reminderMinutesByPrayer: next)));
  }

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
