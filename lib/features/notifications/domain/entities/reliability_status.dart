import 'package:equatable/equatable.dart';
import 'package:quran_app/core/constants/prayer_name.dart';

class MissedAlert extends Equatable {
  final PrayerName prayer;
  final DateTime at;

  const MissedAlert({required this.prayer, required this.at});

  @override
  List<Object?> get props => [prayer, at];
}

class ReliabilityStatus extends Equatable {
  final bool notificationsEnabled;
  final bool channelBlocked;
  final bool exactAlarmsAllowed;
  final bool batteryUnrestricted;
  final bool isXiaomi;
  final bool usesAlarmClock;
  final DateTime? scheduledUntil;
  final DateTime? snapshotUntil;
  final List<MissedAlert> missed;
  final List<MissedAlert> late;

  const ReliabilityStatus({
    required this.notificationsEnabled,
    required this.channelBlocked,
    required this.exactAlarmsAllowed,
    required this.batteryUnrestricted,
    required this.isXiaomi,
    required this.usesAlarmClock,
    this.scheduledUntil,
    this.snapshotUntil,
    this.missed = const [],
    this.late = const [],
  });

  const ReliabilityStatus.ios({
    required this.notificationsEnabled,
    this.scheduledUntil,
  }) : channelBlocked = false,
       exactAlarmsAllowed = true,
       batteryUnrestricted = true,
       isXiaomi = false,
       usesAlarmClock = false,
       snapshotUntil = null,
       missed = const [],
       late = const [];

  ReliabilityStatus copyWith({
    bool? notificationsEnabled,
    bool? channelBlocked,
    bool? exactAlarmsAllowed,
    bool? batteryUnrestricted,
    bool? isXiaomi,
    bool? usesAlarmClock,
    DateTime? scheduledUntil,
    bool clearScheduledUntil = false,
    DateTime? snapshotUntil,
    List<MissedAlert>? missed,
    List<MissedAlert>? late,
  }) {
    return ReliabilityStatus(
      notificationsEnabled: notificationsEnabled ?? this.notificationsEnabled,
      channelBlocked: channelBlocked ?? this.channelBlocked,
      exactAlarmsAllowed: exactAlarmsAllowed ?? this.exactAlarmsAllowed,
      batteryUnrestricted: batteryUnrestricted ?? this.batteryUnrestricted,
      isXiaomi: isXiaomi ?? this.isXiaomi,
      usesAlarmClock: usesAlarmClock ?? this.usesAlarmClock,
      scheduledUntil: clearScheduledUntil
          ? null
          : scheduledUntil ?? this.scheduledUntil,
      snapshotUntil: snapshotUntil ?? this.snapshotUntil,
      missed: missed ?? this.missed,
      late: late ?? this.late,
    );
  }

  @override
  List<Object?> get props => [
    notificationsEnabled,
    channelBlocked,
    exactAlarmsAllowed,
    batteryUnrestricted,
    isXiaomi,
    usesAlarmClock,
    scheduledUntil,
    snapshotUntil,
    missed,
    late,
  ];
}
