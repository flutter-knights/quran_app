import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
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
            isDarkMode: true,
            isFormat12Hours: true,
            isArabic: true,
          ),
        ),
      );
  void updateSettings({
    bool? isDarkMode,
    bool? isFormat12Hours,
    bool? isArabic,
  }) {
    emit(
      SettingsState(
        state.settingsModel.copyWith(
          isDarkMode: isDarkMode,
          isFormat12Hours: isFormat12Hours,
          isArabic: isArabic,
        ),
      ),
    );
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

  void updateAdhanEnabled(PrayerName prayer, bool enabled) {
    final next = Map<PrayerName, bool>.from(
      state.settingsModel.adhanEnabledByPrayer,
    )..[prayer] = enabled;
    emit(SettingsState(
      state.settingsModel.copyWith(adhanEnabledByPrayer: next),
    ));
  }

  void updateReminderMinutes(PrayerName prayer, int minutes) {
    assert(
      Settings.validReminderMinutes.contains(minutes),
      'reminder minutes must be one of ${Settings.validReminderMinutes}, '
      'got $minutes',
    );
    final next = Map<PrayerName, int>.from(
      state.settingsModel.reminderMinutesByPrayer,
    )..[prayer] = minutes;
    emit(SettingsState(
      state.settingsModel.copyWith(reminderMinutesByPrayer: next),
    ));
  }

  @override
  SettingsState? fromJson(Map<String, dynamic> json) {
    return SettingsState(SettingsModel.fromMap(json));
  }

  @override
  Map<String, dynamic>? toJson(SettingsState state) {
    return state.settingsModel.toMap();
  }
}
