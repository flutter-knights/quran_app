import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/data/models/reliability_status_model.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';

void main() {
  test('ReliabilityStatusModel.fromMap parses every field', () {
    final s = ReliabilityStatusModel.fromMap({
      'notificationsEnabled': true,
      'channelBlocked': false,
      'exactAlarmsAllowed': true,
      'batteryUnrestricted': false,
      'isXiaomi': true,
      'usesAlarmClock': true,
      'scheduledUntil': DateTime(2026, 11, 21, 18, 16).millisecondsSinceEpoch,
      'snapshotUntil': '2026-12-31',
      'missed': [
        {
          'prayer': 'isha',
          'at': DateTime(2026, 11, 14, 18, 40).millisecondsSinceEpoch,
        },
      ],
      'late': [
        {
          'prayer': 'fajr',
          'at': DateTime(2026, 11, 15, 4, 58).millisecondsSinceEpoch,
        },
      ],
    });
    expect(
      s.missed.single,
      MissedAlert(prayer: PrayerName.isha, at: DateTime(2026, 11, 14, 18, 40)),
    );
    expect(
      s.late.single,
      MissedAlert(prayer: PrayerName.fajr, at: DateTime(2026, 11, 15, 4, 58)),
    );
    expect(s.scheduledUntil, DateTime(2026, 11, 21, 18, 16));
    expect(s.snapshotUntil, DateTime(2026, 12, 31));
    expect(s.notificationsEnabled, isTrue);
    expect(s.channelBlocked, isFalse);
    expect(s.exactAlarmsAllowed, isTrue);
    expect(s.batteryUnrestricted, isFalse);
    expect(s.isXiaomi, isTrue);
    expect(s.usesAlarmClock, isTrue);
  });

  test('missing or mistyped fields fall back safely', () {
    final s = ReliabilityStatusModel.fromMap({
      'missed': [
        {'prayer': 'sunset', 'at': 'x'},
        {'prayer': 'asr', 'at': 'x'},
        {'prayer': 'sunrise', 'at': 1},
        'junk',
      ],
      'late': 'nope',
      'exactAlarmsAllowed': 'yes',
      'snapshotUntil': 'not a date',
      'scheduledUntil': '123',
    });
    expect(s.notificationsEnabled, isTrue);
    expect(s.exactAlarmsAllowed, isTrue);
    expect(s.batteryUnrestricted, isTrue);
    expect(s.channelBlocked, isFalse);
    expect(s.isXiaomi, isFalse);
    expect(s.usesAlarmClock, isFalse);
    expect(s.missed, isEmpty);
    expect(s.late, isEmpty);
    expect(s.scheduledUntil, isNull);
    expect(s.snapshotUntil, isNull);
  });

  test('ReliabilityStatus.ios has no Android problems', () {
    final s = ReliabilityStatus.ios(
      notificationsEnabled: false,
      scheduledUntil: DateTime(2026, 11, 20),
    );
    expect(s.notificationsEnabled, isFalse);
    expect(s.exactAlarmsAllowed, isTrue);
    expect(s.batteryUnrestricted, isTrue);
    expect(s.channelBlocked, isFalse);
    expect(s.isXiaomi, isFalse);
    expect(s.usesAlarmClock, isFalse);
    expect(s.missed, isEmpty);
    expect(s.late, isEmpty);
    expect(s.scheduledUntil, DateTime(2026, 11, 20));
  });

  test('copyWith replaces fields and clears scheduledUntil', () {
    final s = ReliabilityStatus.ios(
      notificationsEnabled: true,
      scheduledUntil: DateTime(2026, 11, 20),
    );
    final missed = [
      MissedAlert(prayer: PrayerName.asr, at: DateTime(2026, 11, 15, 15)),
    ];
    final next = s.copyWith(isXiaomi: true, missed: missed);
    expect(next.isXiaomi, isTrue);
    expect(next.missed, missed);
    expect(next.scheduledUntil, DateTime(2026, 11, 20));
    expect(s.copyWith(clearScheduledUntil: true).scheduledUntil, isNull);
  });
}
