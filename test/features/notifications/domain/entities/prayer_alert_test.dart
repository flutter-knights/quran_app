import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/strip_style.dart';

void main() {
  test('effectiveReminderMinutes needs enabled and reminderEnabled', () {
    expect(
      const PrayerAlert(
        reminderEnabled: true,
        reminderMinutes: 15,
      ).effectiveReminderMinutes,
      15,
    );
    expect(
      const PrayerAlert(
        enabled: false,
        reminderEnabled: true,
      ).effectiveReminderMinutes,
      isNull,
    );
    expect(const PrayerAlert().effectiveReminderMinutes, isNull);
  });

  test('defaults match spec §6', () {
    const a = PrayerAlert();
    expect(
      [
        a.enabled,
        a.sound,
        a.ringInSilent,
        a.reminderEnabled,
        a.reminderMinutes,
        a.reminderSound,
      ],
      [true, PrayerSound.adhan, false, false, 10, ReminderSound.tone],
    );
    expect(
      const StripStyle(),
      const StripStyle(
        expanded: false,
        showCountdown: true,
        highlight: StripHighlight.app,
        background: StripBackground.auto,
        shape: StripShape.rounded,
      ),
    );
  });

  test('alertPrayers lists the five prayers in order without sunrise', () {
    expect(alertPrayers, [
      PrayerName.fajr,
      PrayerName.dhuhr,
      PrayerName.asr,
      PrayerName.maghrib,
      PrayerName.isha,
    ]);
  });

  test('copyWith replaces only the given fields', () {
    const a = PrayerAlert();
    expect(
      a.copyWith(sound: PrayerSound.vibrate, reminderMinutes: 30),
      const PrayerAlert(sound: PrayerSound.vibrate, reminderMinutes: 30),
    );
    expect(
      const StripStyle().copyWith(shape: StripShape.pill),
      const StripStyle(shape: StripShape.pill),
    );
  });

  test('clampMinutes keeps reminder minutes within 1..60', () {
    expect(PrayerAlert.clampMinutes(0), 1);
    expect(PrayerAlert.clampMinutes(-3), 1);
    expect(PrayerAlert.clampMinutes(42), 42);
    expect(PrayerAlert.clampMinutes(120), 60);
  });
}
