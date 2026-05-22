import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

late Directory _tempDir;

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    _tempDir = Directory.systemTemp.createTempSync('settings_cubit_test_');
    HydratedBloc.storage = await HydratedStorage.build(
      storageDirectory: HydratedStorageDirectory(_tempDir.path),
    );
  });

  tearDownAll(() async {
    await HydratedBloc.storage.close();
    _tempDir.deleteSync(recursive: true);
  });

  setUp(() async {
    await HydratedBloc.storage.clear();
  });

  test('default state has speed=1.0 and reciter=alafasy', () {
    final cubit = SettingsCubit();
    expect(cubit.state.settingsModel.playbackSpeed, 1.0);
    expect(cubit.state.settingsModel.defaultReciter, Reciter.alafasy);
  });

  blocTest<SettingsCubit, SettingsState>(
    'updatePlaybackSpeed emits new speed',
    build: () => SettingsCubit(),
    act: (c) => c.updatePlaybackSpeed(1.5),
    expect: () => [
      isA<SettingsState>().having(
        (s) => s.settingsModel.playbackSpeed, 'speed', 1.5),
    ],
  );

  blocTest<SettingsCubit, SettingsState>(
    'updateDefaultReciter emits new reciter',
    build: () => SettingsCubit(),
    act: (c) => c.updateDefaultReciter(Reciter.husary),
    expect: () => [
      isA<SettingsState>().having(
        (s) => s.settingsModel.defaultReciter, 'reciter', Reciter.husary),
    ],
  );

  test('toMap / fromMap round-trips new fields', () {
    final model = SettingsModel(
      isDarkMode: true,
      isFormat12Hours: false,
      isArabic: true,
      playbackSpeed: 1.25,
      defaultReciter: Reciter.minshawyMurattal,
    );
    final round = SettingsModel.fromMap(model.toMap());
    expect(round.playbackSpeed, 1.25);
    expect(round.defaultReciter, Reciter.minshawyMurattal);
  });

  test('toMap / fromMap round-trips isPrayerStripPinned', () {
    final model = SettingsModel(
      isDarkMode: true,
      isFormat12Hours: false,
      isArabic: true,
      playbackSpeed: 1.0,
      defaultReciter: Reciter.alafasy,
      isPrayerStripPinned: true,
    );
    final round = SettingsModel.fromMap(model.toMap());
    expect(round.isPrayerStripPinned, true);
  });

  test('fromMap defaults isPrayerStripPinned to false when missing', () {
    final round = SettingsModel.fromMap({
      'isArabic': true,
      'isDarkMode': true,
      'isFormat12Hours': true,
      'playbackSpeed': 1.0,
      'defaultReciter': 'alafasy',
    });
    expect(round.isPrayerStripPinned, false);
  });
}
