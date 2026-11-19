import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class _MemStorage implements Storage {
  final _m = <String, dynamic>{};
  @override
  dynamic read(String key) => _m[key];
  @override
  Future<void> write(String key, dynamic value) async => _m[key] = value;
  @override
  Future<void> delete(String key) async => _m.remove(key);
  @override
  Future<void> clear() async => _m.clear();
  @override
  Future<void> close() async {}
}

void main() {
  setUpAll(() => HydratedBloc.storage = _MemStorage());

  test('updatePageBrightness clamps to [0.3, 1.0]', () {
    final c = SettingsCubit();
    c.updatePageBrightness(0.1);
    expect(c.state.settingsModel.pageBrightness, 0.3);
    c.updatePageBrightness(0.7);
    expect(c.state.settingsModel.pageBrightness, 0.7);
  });

  test('updateReadingMode switches mode', () {
    final c = SettingsCubit();
    c.updateReadingMode(MushafReadingMode.scroll);
    expect(c.state.settingsModel.readingMode, MushafReadingMode.scroll);
  });

  test('updatePrayerAlert clamps reminder minutes to 1..60', () {
    final cubit = SettingsCubit();
    cubit.updatePrayerAlert(
      PrayerName.asr,
      const PrayerAlert(reminderMinutes: 90),
    );
    expect(
      cubit.state.settingsModel.prayerAlerts[PrayerName.asr]!.reminderMinutes,
      60,
    );
    cubit.updatePrayerAlert(
      PrayerName.asr,
      const PrayerAlert(reminderMinutes: 0),
    );
    expect(
      cubit.state.settingsModel.prayerAlerts[PrayerName.asr]!.reminderMinutes,
      1,
    );
  });

  test('applyAlertToAll sets all five prayers', () {
    final cubit = SettingsCubit();
    cubit.applyAlertToAll(
      enabled: true,
      sound: PrayerSound.tone,
      reminderEnabled: true,
      reminderMinutes: 5,
    );
    expect(cubit.state.settingsModel.prayerAlerts.values.toSet(), {
      const PrayerAlert(
        sound: PrayerSound.tone,
        reminderEnabled: true,
        reminderMinutes: 5,
      ),
    });
    expect(cubit.state.settingsModel.prayerAlerts.keys, alertPrayers);
    cubit.applyAlertToAll(enabled: false);
    expect(cubit.state.settingsModel.enabledAlertCount, 0);
  });

  test('notifications are needed by any alert or the strip', () {
    final cubit = SettingsCubit();
    cubit.applyAlertToAll(enabled: true);
    expect(cubit.state.settingsModel.usesNotifications, isTrue);
    cubit.applyAlertToAll(enabled: false);
    expect(cubit.state.settingsModel.usesNotifications, isFalse);
    cubit.updatePrayerStripPinned(true);
    expect(cubit.state.settingsModel.usesNotifications, isTrue);
  });

  test('updateStripStyle stores the style', () {
    final cubit = SettingsCubit();
    cubit.updateStripStyle(const StripStyle(shape: StripShape.pill));
    expect(
      cubit.state.settingsModel.stripStyle,
      const StripStyle(shape: StripShape.pill),
    );
  });

  test('markAlertsIntroSeen sets the flag', () {
    final cubit = SettingsCubit();
    cubit.markAlertsIntroSeen();
    expect(cubit.state.settingsModel.alertsIntroSeen, isTrue);
  });

  test('completeOnboarding also marks alertsIntroSeen', () async {
    await HydratedBloc.storage.clear();
    final cubit = SettingsCubit();
    expect(cubit.state.settingsModel.alertsIntroSeen, isFalse);
    cubit.completeOnboarding();
    expect(cubit.state.settingsModel.hasCompletedOnboarding, isTrue);
    expect(cubit.state.settingsModel.alertsIntroSeen, isTrue);
  });

  test('clearXiaomiConfirmations resets both flags', () {
    final cubit = SettingsCubit();
    cubit
      ..setXiaomiAutostartConfirmed(true)
      ..setXiaomiBatteryConfirmed(true);
    expect(cubit.state.settingsModel.xiaomiAutostartConfirmed, isTrue);
    expect(cubit.state.settingsModel.xiaomiBatteryConfirmed, isTrue);
    cubit.clearXiaomiConfirmations();
    expect(cubit.state.settingsModel.xiaomiAutostartConfirmed, isFalse);
    expect(cubit.state.settingsModel.xiaomiBatteryConfirmed, isFalse);
  });
}
