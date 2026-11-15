import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';

enum AlertsStatusKind { allOff, off, attention, ok, okNoDate }

AlertsStatusKind resolveAlertsStatus({
  required int enabledCount,
  required ReliabilityStatus status,
  required bool isAndroid,
  required DateTime now,
}) {
  if (enabledCount == 0) return AlertsStatusKind.allOff;
  if (!status.notificationsEnabled) return AlertsStatusKind.off;
  final until = status.scheduledUntil;
  final batteryMatters = status.isXiaomi || !status.usesAlarmClock;
  if (status.channelBlocked ||
      !status.exactAlarmsAllowed ||
      status.missed.isNotEmpty ||
      status.late.isNotEmpty ||
      (until != null && until.isBefore(now)) ||
      (isAndroid && until == null) ||
      (batteryMatters && !status.batteryUnrestricted)) {
    return AlertsStatusKind.attention;
  }
  return until != null ? AlertsStatusKind.ok : AlertsStatusKind.okNoDate;
}
