import 'package:equatable/equatable.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';

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

  @override
  SettingsState? fromJson(Map<String, dynamic> json) {
    return SettingsState(SettingsModel.fromMap(json));
  }

  @override
  Map<String, dynamic>? toJson(SettingsState state) {
    return state.settingsModel.toMap();
  }
}
