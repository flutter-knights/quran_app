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
