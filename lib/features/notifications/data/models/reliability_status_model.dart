import 'package:collection/collection.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';

class ReliabilityStatusModel extends ReliabilityStatus {
  const ReliabilityStatusModel({
    required super.notificationsEnabled,
    required super.channelBlocked,
    required super.exactAlarmsAllowed,
    required super.batteryUnrestricted,
    required super.isXiaomi,
    required super.usesAlarmClock,
    super.scheduledUntil,
    super.snapshotUntil,
    super.missed,
    super.late,
  });

  factory ReliabilityStatusModel.fromMap(Map<String, Object?> map) {
    bool flag(String key, bool fallback) {
      final v = map[key];
      return v is bool ? v : fallback;
    }

    final scheduledUntil = map['scheduledUntil'];
    final snapshotUntil = map['snapshotUntil'];
    return ReliabilityStatusModel(
      notificationsEnabled: flag('notificationsEnabled', true),
      channelBlocked: flag('channelBlocked', false),
      exactAlarmsAllowed: flag('exactAlarmsAllowed', true),
      batteryUnrestricted: flag('batteryUnrestricted', true),
      isXiaomi: flag('isXiaomi', false),
      usesAlarmClock: flag('usesAlarmClock', false),
      scheduledUntil: _epoch(scheduledUntil),
      snapshotUntil: snapshotUntil is String
          ? DateTime.tryParse(snapshotUntil)
          : null,
      missed: _alerts(map['missed']),
      late: _alerts(map['late']),
    );
  }

  static List<MissedAlert> _alerts(Object? raw) {
    if (raw is! List) return const [];
    return [
      for (final e in raw)
        if (e is Map) ?_alert(e['prayer'], e['at']),
    ];
  }

  static MissedAlert? _alert(Object? prayer, Object? at) {
    final p = alertPrayers.firstWhereOrNull((p) => p.name == prayer);
    final time = _epoch(at);
    if (p == null || time == null) return null;
    return MissedAlert(prayer: p, at: time);
  }

  static const _maxEpochMs = 8640000000000000;

  static DateTime? _epoch(Object? raw) => raw is int && raw.abs() <= _maxEpochMs
      ? DateTime.fromMillisecondsSinceEpoch(raw)
      : null;
}
