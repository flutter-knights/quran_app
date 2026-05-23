import 'dart:io';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
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

  blocTest<SettingsCubit, SettingsState>(
    'updatePrayerStripPinned(true) emits new state with flag true',
    build: () => SettingsCubit(),
    act: (c) => c.updatePrayerStripPinned(true),
    expect: () => [
      isA<SettingsState>().having(
        (s) => s.settingsModel.isPrayerStripPinned,
        'isPrayerStripPinned',
        true,
      ),
    ],
  );

  blocTest<SettingsCubit, SettingsState>(
    'updatePrayerStripPinned(false) emits new state with flag false',
    build: () => SettingsCubit()..updatePrayerStripPinned(true),
    act: (c) => c.updatePrayerStripPinned(false),
    expect: () => [
      isA<SettingsState>().having(
        (s) => s.settingsModel.isPrayerStripPinned,
        'isPrayerStripPinned',
        false,
      ),
    ],
  );

  test('toMap / fromMap round-trips adhanEnabledByPrayer', () {
    final model = SettingsModel(
      isDarkMode: true,
      isFormat12Hours: false,
      isArabic: true,
      adhanEnabledByPrayer: const {
        PrayerName.fajr: false,
        PrayerName.dhuhr: true,
        PrayerName.asr: true,
        PrayerName.maghrib: true,
        PrayerName.isha: false,
      },
    );
    final round = SettingsModel.fromMap(model.toMap());
    expect(round.adhanEnabledByPrayer[PrayerName.fajr], false);
    expect(round.adhanEnabledByPrayer[PrayerName.dhuhr], true);
    expect(round.adhanEnabledByPrayer[PrayerName.isha], false);
  });

  test('toMap / fromMap round-trips reminderMinutesByPrayer', () {
    final model = SettingsModel(
      isDarkMode: true,
      isFormat12Hours: false,
      isArabic: true,
      reminderMinutesByPrayer: const {
        PrayerName.fajr: 15,
        PrayerName.dhuhr: 0,
        PrayerName.asr: 10,
        PrayerName.maghrib: 5,
        PrayerName.isha: 0,
      },
    );
    final round = SettingsModel.fromMap(model.toMap());
    expect(round.reminderMinutesByPrayer[PrayerName.fajr], 15);
    expect(round.reminderMinutesByPrayer[PrayerName.asr], 10);
    expect(round.reminderMinutesByPrayer[PrayerName.maghrib], 5);
  });

  test('fromMap applies default adhan-enabled map (all true) when missing', () {
    final round = SettingsModel.fromMap({
      'isArabic': true,
      'isDarkMode': true,
      'isFormat12Hours': true,
      'playbackSpeed': 1.0,
      'defaultReciter': 'alafasy',
      'isPrayerStripPinned': false,
    });
    for (final p in [
      PrayerName.fajr, PrayerName.dhuhr, PrayerName.asr,
      PrayerName.maghrib, PrayerName.isha,
    ]) {
      expect(round.adhanEnabledByPrayer[p], true, reason: '$p should default to true');
    }
  });

  test('fromMap applies default reminder map (all zero) when missing', () {
    final round = SettingsModel.fromMap({
      'isArabic': true,
      'isDarkMode': true,
      'isFormat12Hours': true,
      'playbackSpeed': 1.0,
      'defaultReciter': 'alafasy',
      'isPrayerStripPinned': false,
    });
    for (final p in [
      PrayerName.fajr, PrayerName.dhuhr, PrayerName.asr,
      PrayerName.maghrib, PrayerName.isha,
    ]) {
      expect(round.reminderMinutesByPrayer[p], 0, reason: '$p should default to 0');
    }
  });

  test('fromMap merges partial adhanEnabledByPrayer with defaults', () {
    final round = SettingsModel.fromMap({
      'isArabic': true,
      'isDarkMode': true,
      'isFormat12Hours': true,
      'playbackSpeed': 1.0,
      'defaultReciter': 'alafasy',
      'isPrayerStripPinned': false,
      'adhanEnabledByPrayer': {
        'fajr': false,
        'dhuhr': false,
      },
    });
    // Provided keys win:
    expect(round.adhanEnabledByPrayer[PrayerName.fajr], false);
    expect(round.adhanEnabledByPrayer[PrayerName.dhuhr], false);
    // Missing keys take the default (true):
    expect(round.adhanEnabledByPrayer[PrayerName.asr], true);
    expect(round.adhanEnabledByPrayer[PrayerName.maghrib], true);
    expect(round.adhanEnabledByPrayer[PrayerName.isha], true);
  });

  test('fromMap drops out-of-range reminder minutes', () {
    final round = SettingsModel.fromMap({
      'isArabic': true,
      'isDarkMode': true,
      'isFormat12Hours': true,
      'playbackSpeed': 1.0,
      'defaultReciter': 'alafasy',
      'isPrayerStripPinned': false,
      'reminderMinutesByPrayer': {
        'fajr': 7,    // invalid — should be dropped, default 0 wins
        'dhuhr': 10,  // valid
      },
    });
    expect(round.reminderMinutesByPrayer[PrayerName.fajr], 0);
    expect(round.reminderMinutesByPrayer[PrayerName.dhuhr], 10);
  });
}
