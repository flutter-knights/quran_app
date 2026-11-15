import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';
import 'package:quran_app/features/settings/domain/entities/settings.dart';

void main() {
  group('SettingsModel migration', () {
    test('derives prayerAlerts from the legacy maps', () {
      final m = SettingsModel.fromMap({
        'adhanEnabledByPrayer': {'fajr': true, 'dhuhr': false, 'asr': true},
        'reminderMinutesByPrayer': {'fajr': 15, 'dhuhr': 5, 'asr': 0},
      });
      expect(
        m.prayerAlerts[PrayerName.fajr],
        const PrayerAlert(reminderEnabled: true, reminderMinutes: 15),
      );
      expect(
        m.prayerAlerts[PrayerName.dhuhr],
        const PrayerAlert(
          enabled: false,
          reminderEnabled: true,
          reminderMinutes: 5,
        ),
      );
      expect(m.prayerAlerts[PrayerName.asr], const PrayerAlert());
      expect(m.prayerAlerts.keys, alertPrayers);
      expect(
        m.prayerAlerts[PrayerName.dhuhr]!.effectiveReminderMinutes,
        isNull,
      );
    });

    test('clamps out-of-range and ignores wrong types without throwing', () {
      final m = SettingsModel.fromMap({
        'adhanEnabledByPrayer': {'fajr': 'yes'},
        'reminderMinutesByPrayer': {'fajr': 120, 'isha': -3, 'asr': '7'},
      });
      expect(m.prayerAlerts[PrayerName.fajr]!.enabled, isTrue);
      expect(m.prayerAlerts[PrayerName.fajr]!.reminderMinutes, 60);
      expect(m.prayerAlerts[PrayerName.isha], const PrayerAlert());
      expect(m.prayerAlerts[PrayerName.asr], const PrayerAlert());
    });

    test(
      'prayerAlerts wins over legacy maps and unknown enum names fall back',
      () {
        final m = SettingsModel.fromMap({
          'prayerAlerts': {
            'fajr': {
              'sound': 'trumpet',
              'reminderMinutes': 0,
              'reminderSound': 'silent',
            },
          },
          'adhanEnabledByPrayer': {'fajr': false},
        });
        expect(
          m.prayerAlerts[PrayerName.fajr],
          const PrayerAlert(
            reminderMinutes: 1,
            reminderSound: ReminderSound.silent,
          ),
        );
      },
    );

    test('upgrader has alertsIntroSeen false and ringInSilent false', () {
      final m = SettingsModel.fromMap({
        'adhanEnabledByPrayer': {'fajr': true},
      });
      expect(m.alertsIntroSeen, isFalse);
      expect(m.prayerAlerts.values.every((a) => !a.ringInSilent), isTrue);
    });

    test('malformed stripStyle falls back to defaults', () {
      final m = SettingsModel.fromMap({
        'stripStyle': {'expanded': 'no', 'highlight': 'neon', 'shape': 'pill'},
      });
      expect(m.stripStyle, const StripStyle(shape: StripShape.pill));
      expect(
        SettingsModel.fromMap({'stripStyle': 3}).stripStyle,
        const StripStyle(),
      );
    });

    test('round-trips every new field', () {
      const alerts = {
        PrayerName.fajr: PrayerAlert(
          sound: PrayerSound.vibrate,
          ringInSilent: true,
          reminderEnabled: true,
          reminderMinutes: 42,
          reminderSound: ReminderSound.vibrate,
        ),
      };
      final m = SettingsModel(isFormat12Hours: false, isArabic: true).copyWith(
        prayerAlerts: {...Settings.defaultPrayerAlerts, ...alerts},
        stripStyle: const StripStyle(
          expanded: false,
          highlight: StripHighlight.maroon,
          background: StripBackground.rose,
          shape: StripShape.outline,
        ),
        alertsIntroSeen: true,
        xiaomiAutostartConfirmed: true,
        xiaomiBatteryConfirmed: true,
      );
      expect(SettingsModel.fromMap(m.toMap()), m);
      expect(m.toMap().containsKey('adhanEnabledByPrayer'), isFalse);
    });
  });
}
