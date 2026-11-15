import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/notifications/ios_alert_plan.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';

PrayerTimes dayOn(int day, {String fajr = '04:52'}) {
  final key = '$day-11-2026';
  return PrayerTimes(
    key: key,
    timings: {
      PrayerName.fajr: fajr,
      PrayerName.sunrise: '06:18',
      PrayerName.dhuhr: '11:41',
      PrayerName.asr: '14:39',
      PrayerName.maghrib: '16:58',
      PrayerName.isha: '18:16',
    },
    date: Date(
      month: '',
      weekDay: '',
      day: '$day',
      year: '1448',
      enMonth: '',
      enWeekDay: '',
      gregorianDate: key,
    ),
  );
}

void main() {
  final eightDays = [for (var d = 15; d < 23; d++) dayOn(d)];
  final allWithReminders = {
    for (final p in alertPrayers)
      p: const PrayerAlert(reminderEnabled: true, reminderMinutes: 10),
  };

  test('iosDayCount follows floor(60 / requests), capped at 12', () {
    expect(iosDayCount(10), 6);
    expect(iosDayCount(6), 10);
    expect(iosDayCount(5), 12);
    expect(iosDayCount(1), 12);
    expect(iosDayCount(0), 0);
  });

  test('ids, sounds and day limit with all alerts and reminders on', () {
    final reqs = planIosAlerts(
      days: eightDays,
      alerts: allWithReminders,
      localeCode: 'ar',
      now: DateTime(2026, 11, 15),
    );
    expect(reqs.where((r) => r.id < 200).map((r) => r.id).reduce(max), 54);
    expect(reqs.firstWhere((r) => r.id == 0).sound, IosSound.fajrClip);
    expect(reqs.firstWhere((r) => r.id == 1).sound, IosSound.normalClip);
    expect(
      reqs.firstWhere((r) => r.id == 200).at,
      DateTime(2026, 11, 15, 4, 42),
    );
    expect(reqs.length, 60);
    expect(reqs.firstWhere((r) => r.id == 0).title, 'الفجر');
    expect(reqs.firstWhere((r) => r.id == 0).body, 'حان موعد صلاة الفجر');
    expect(reqs.firstWhere((r) => r.id == 200).title, 'تذكير الفجر');
    expect(reqs.firstWhere((r) => r.id == 200).body, 'اقتربت صلاة الفجر');
    expect(
      reqs.firstWhere((r) => r.id == 54).at,
      DateTime(2026, 11, 20, 18, 16),
    );
  });

  test('English copy mirrors the Android strings', () {
    final reqs = planIosAlerts(
      days: eightDays.take(1).toList(),
      alerts: allWithReminders,
      localeCode: 'en',
      now: DateTime(2026, 11, 15),
    );
    final asr = reqs.firstWhere((r) => r.id == 2);
    final asrReminder = reqs.firstWhere((r) => r.id == 202);
    expect(asr.title, 'Asr');
    expect(asr.body, "It's time for Asr prayer");
    expect(asrReminder.title, 'Asr reminder');
    expect(asrReminder.body, 'Asr prayer is coming up');
  });

  test(
    'tone uses the default sound, vibrate and silent use none, disabled is skipped',
    () {
      final reqs = planIosAlerts(
        days: eightDays.take(1).toList(),
        alerts: {
          PrayerName.fajr: const PrayerAlert(sound: PrayerSound.tone),
          PrayerName.dhuhr: const PrayerAlert(
            sound: PrayerSound.vibrate,
            reminderEnabled: true,
            reminderSound: ReminderSound.vibrate,
          ),
          PrayerName.asr: const PrayerAlert(
            enabled: false,
            reminderEnabled: true,
          ),
          PrayerName.maghrib: const PrayerAlert(
            sound: PrayerSound.silent,
            reminderEnabled: true,
          ),
        },
        localeCode: 'en',
        now: DateTime(2026, 11, 15),
      );
      expect(reqs.firstWhere((r) => r.id == 0).sound, IosSound.defaultSound);
      expect(reqs.firstWhere((r) => r.id == 1).sound, IosSound.none);
      expect(reqs.firstWhere((r) => r.id == 201).sound, IosSound.none);
      expect(reqs.firstWhere((r) => r.id == 3).sound, IosSound.none);
      expect(reqs.firstWhere((r) => r.id == 203).sound, IosSound.defaultSound);
      expect(reqs.any((r) => r.id == 2 || r.id == 202), isFalse);
    },
  );

  test('past triggers are skipped on the first day', () {
    final reqs = planIosAlerts(
      days: eightDays,
      alerts: allWithReminders,
      localeCode: 'en',
      now: DateTime(2026, 11, 15, 12),
    );
    expect(reqs.any((r) => r.id == 0 || r.id == 1), isFalse);
    expect(reqs.any((r) => r.id == 200 || r.id == 201), isFalse);
    expect(
      reqs.firstWhere((r) => r.id == 2).at,
      DateTime(2026, 11, 15, 14, 39),
    );
    expect(
      reqs.firstWhere((r) => r.id == 10).at,
      DateTime(2026, 11, 16, 4, 52),
    );
  });

  test('between a reminder and its adhan only the adhan is kept', () {
    final reqs = planIosAlerts(
      days: eightDays,
      alerts: allWithReminders,
      localeCode: 'en',
      now: DateTime(2026, 11, 15, 4, 45),
    );
    expect(reqs.any((r) => r.id == 200), isFalse);
    expect(reqs.firstWhere((r) => r.id == 0).at, DateTime(2026, 11, 15, 4, 52));
  });

  test('after Isha the first scheduled day is tomorrow', () {
    final reqs = planIosAlerts(
      days: eightDays,
      alerts: allWithReminders,
      localeCode: 'en',
      now: DateTime(2026, 11, 15, 19),
    );
    expect(reqs.firstWhere((r) => r.id == 0).at, DateTime(2026, 11, 16, 4, 52));
    expect(reqs.length, 60);
    expect(
      reqs.firstWhere((r) => r.id == 54).at,
      DateTime(2026, 11, 21, 18, 16),
    );
  });

  test('fewer requests per day schedule more days, up to the days given', () {
    final reqs = planIosAlerts(
      days: eightDays,
      alerts: {
        for (final p in alertPrayers)
          p: PrayerAlert(enabled: p == PrayerName.fajr),
      },
      localeCode: 'en',
      now: DateTime(2026, 11, 15),
    );
    expect(reqs.map((r) => r.id), [0, 10, 20, 30, 40, 50, 60, 70]);
  });

  test('duplicate, past and malformed days are skipped without throwing', () {
    final reqs = planIosAlerts(
      days: [
        dayOn(16, fajr: '25:00'),
        dayOn(14),
        dayOn(15),
        dayOn(15, fajr: '05:00'),
        dayOn(17, fajr: '5:7x'),
        dayOn(18, fajr: ''),
        dayOn(19, fajr: '04:60'),
        dayOn(20),
      ],
      alerts: {
        for (final p in alertPrayers)
          p: PrayerAlert(enabled: p == PrayerName.fajr),
      },
      localeCode: 'en',
      now: DateTime(2026, 11, 15),
    );
    expect(reqs.map((r) => (r.id, r.at)), [
      (0, DateTime(2026, 11, 15, 4, 52)),
      (10, DateTime(2026, 11, 20, 4, 52)),
    ]);
  });

  test('no enabled alert schedules nothing', () {
    final reqs = planIosAlerts(
      days: eightDays,
      alerts: {
        for (final p in alertPrayers) p: const PrayerAlert(enabled: false),
      },
      localeCode: 'en',
      now: DateTime(2026, 11, 15),
    );
    expect(reqs, isEmpty);
  });

  test('clip sounds name the bundled files and none is silent', () {
    expect(IosSound.fajrClip.file, 'fajr_adhan.caf');
    expect(IosSound.normalClip.file, 'normal_adhan.caf');
    expect(IosSound.defaultSound.file, isNull);
    expect(IosSound.defaultSound.audible, isTrue);
    expect(IosSound.none.audible, isFalse);
  });
}
