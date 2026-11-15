import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/services/alerts_status_resolver.dart';

void main() {
  group('resolveAlertsStatus', () {
    final ok = ReliabilityStatus(
      notificationsEnabled: true,
      channelBlocked: false,
      exactAlarmsAllowed: true,
      batteryUnrestricted: true,
      isXiaomi: false,
      usesAlarmClock: true,
      scheduledUntil: DateTime(2026, 11, 21, 18, 16),
      snapshotUntil: DateTime(2026, 12, 31),
    );
    final now = DateTime(2026, 11, 15, 12);
    AlertsStatusKind r(
      ReliabilityStatus s, {
      int count = 5,
      bool android = true,
    }) => resolveAlertsStatus(
      enabledCount: count,
      status: s,
      isAndroid: android,
      now: now,
    );

    test('rule 1 wins over everything', () {
      expect(
        r(ok.copyWith(notificationsEnabled: false), count: 0),
        AlertsStatusKind.allOff,
      );
    });
    test('rule 2', () {
      expect(r(ok.copyWith(notificationsEnabled: false)), AlertsStatusKind.off);
    });
    test('rule 3 triggers', () {
      expect(r(ok.copyWith(channelBlocked: true)), AlertsStatusKind.attention);
      expect(
        r(ok.copyWith(exactAlarmsAllowed: false)),
        AlertsStatusKind.attention,
      );
      expect(
        r(
          ok.copyWith(
            missed: [MissedAlert(prayer: PrayerName.isha, at: now)],
          ),
        ),
        AlertsStatusKind.attention,
      );
      expect(
        r(
          ok.copyWith(
            late: [MissedAlert(prayer: PrayerName.asr, at: now)],
          ),
        ),
        AlertsStatusKind.attention,
      );
      expect(
        r(ok.copyWith(scheduledUntil: DateTime(2026, 11, 14))),
        AlertsStatusKind.attention,
      );
      expect(
        r(ok.copyWith(clearScheduledUntil: true)),
        AlertsStatusKind.attention,
      );
      expect(
        r(ok.copyWith(isXiaomi: true, batteryUnrestricted: false)),
        AlertsStatusKind.attention,
      );
    });
    test('battery on non-Xiaomi counts only without alarm clock', () {
      expect(r(ok.copyWith(batteryUnrestricted: false)), AlertsStatusKind.ok);
      expect(
        r(ok.copyWith(batteryUnrestricted: false, usesAlarmClock: false)),
        AlertsStatusKind.attention,
      );
    });
    test('rule 4', () {
      expect(r(ok), AlertsStatusKind.ok);
      expect(
        r(
          const ReliabilityStatus.ios(notificationsEnabled: true),
          android: false,
        ),
        AlertsStatusKind.okNoDate,
      );
    });
  });
}
