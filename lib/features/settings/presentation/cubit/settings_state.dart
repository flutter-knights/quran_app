part of 'settings_cubit.dart';

class SettingsState extends Equatable {
  const SettingsState(this.settingsModel);
  final SettingsModel settingsModel;

  @override
  List<Object> get props => [settingsModel];
}
