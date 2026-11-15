import 'package:flutter_test/flutter_test.dart';
import 'package:hydrated_bloc/hydrated_bloc.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/onboarding/presentation/utils/apply_alerts_choice.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

import '../notifications/presentation/alerts_test_harness.dart';

void main() {
  late SettingsCubit cubit;

  setUpAll(() => HydratedBloc.storage = MemStorage());
  setUp(() async {
    await HydratedBloc.storage.clear();
    cubit = SettingsCubit();
  });
  tearDown(() => cubit.close());

  test('tone with 15 minutes', () {
    applyAlertsChoice(
      cubit,
      const AlertsChoice(sound: PrayerSound.tone, reminderMinutes: 15),
    );
    final a = cubit.state.settingsModel.prayerAlerts[PrayerName.asr]!;
    expect(
      (a.enabled, a.sound, a.reminderEnabled, a.reminderMinutes),
      (true, PrayerSound.tone, true, 15),
    );
  });

  test('no reminder turns reminders off and keeps the stored minutes', () {
    applyAlertsChoice(
      cubit,
      const AlertsChoice(sound: PrayerSound.tone, reminderMinutes: 30),
    );
    applyAlertsChoice(
      cubit,
      const AlertsChoice(sound: PrayerSound.adhan, reminderMinutes: null),
    );
    final alerts = cubit.state.settingsModel.prayerAlerts.values;
    expect(
      alerts.every(
        (a) =>
            a.enabled &&
            a.sound == PrayerSound.adhan &&
            !a.reminderEnabled &&
            a.reminderMinutes == 30,
      ),
      isTrue,
    );
  });

  group('alertsChoiceFrom', () {
    test('reads the first enabled prayer', () {
      final alerts = {
        PrayerName.fajr: const PrayerAlert(enabled: false),
        PrayerName.dhuhr: const PrayerAlert(
          sound: PrayerSound.tone,
          reminderEnabled: true,
          reminderMinutes: 15,
        ),
        PrayerName.asr: const PrayerAlert(),
      };
      expect(
        alertsChoiceFrom(alerts),
        const AlertsChoice(sound: PrayerSound.tone, reminderMinutes: 15),
      );
    });

    test('everything off reads as no alert', () {
      final alerts = {
        for (final p in alertPrayers) p: const PrayerAlert(enabled: false),
      };
      expect(alertsChoiceFrom(alerts), const AlertsChoice());
    });

    test('defaults read as adhan without a reminder', () {
      expect(
        alertsChoiceFrom(cubit.state.settingsModel.prayerAlerts),
        const AlertsChoice(sound: PrayerSound.adhan),
      );
    });
  });

  test('no alert disables every prayer', () {
    applyAlertsChoice(
      cubit,
      const AlertsChoice(sound: null, reminderMinutes: 10),
    );
    expect(
      cubit.state.settingsModel.prayerAlerts.values.every((a) => !a.enabled),
      isTrue,
    );
  });
}
