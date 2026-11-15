import 'package:equatable/equatable.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';

class PrayerStripState extends Equatable {
  final List<PrayerCell> cells;
  final int nextPrayerIndex;

  /// Calendar day this snapshot describes, `"dd-MM-yyyy"` (== `PrayerTimes.date.gregorianDate`).
  final String dateKey;

  final String hijriDateLabel;
  final String weekdayLabel;
  final String localeCode;
  final bool isFriday;

  const PrayerStripState({
    required this.cells,
    required this.nextPrayerIndex,
    required this.dateKey,
    required this.hijriDateLabel,
    required this.weekdayLabel,
    required this.localeCode,
    required this.isFriday,
  });

  PrayerStripState copyWith({
    List<PrayerCell>? cells,
    int? nextPrayerIndex,
    String? dateKey,
    String? hijriDateLabel,
    String? weekdayLabel,
    String? localeCode,
    bool? isFriday,
  }) {
    return PrayerStripState(
      cells: cells ?? this.cells,
      nextPrayerIndex: nextPrayerIndex ?? this.nextPrayerIndex,
      dateKey: dateKey ?? this.dateKey,
      hijriDateLabel: hijriDateLabel ?? this.hijriDateLabel,
      weekdayLabel: weekdayLabel ?? this.weekdayLabel,
      localeCode: localeCode ?? this.localeCode,
      isFriday: isFriday ?? this.isFriday,
    );
  }

  Map<String, Object> toJson() => {
    'cells': cells
        .map(
          (c) => {
            'label': c.label,
            'time': c.timeFormatted,
            'timeFull': c.timeFull,
            'minutes': c.minutes,
            'nextLabel': c.nextLabel,
          },
        )
        .toList(),
    'nextPrayerIndex': nextPrayerIndex,
    'dateKey': dateKey,
    'hijriDateLabel': hijriDateLabel,
    'weekdayLabel': weekdayLabel,
    'localeCode': localeCode,
    'isFriday': isFriday,
  };

  factory PrayerStripState.fromJson(Map<String, Object?> json) {
    final rawCells = (json['cells'] as List).cast<Map<String, Object?>>();
    return PrayerStripState(
      cells: rawCells
          .map(
            (m) => PrayerCell(
              label: m['label'] as String,
              timeFormatted: m['time'] as String,
              timeFull: m['timeFull'] as String?,
              minutes: m['minutes'] as int,
              nextLabel: (m['nextLabel'] as String?) ?? '',
            ),
          )
          .toList(),
      nextPrayerIndex: json['nextPrayerIndex'] as int,
      dateKey: (json['dateKey'] as String?) ?? '',
      hijriDateLabel: json['hijriDateLabel'] as String,
      weekdayLabel: (json['weekdayLabel'] as String?) ?? '',
      localeCode: json['localeCode'] as String,
      isFriday: json['isFriday'] as bool,
    );
  }

  @override
  List<Object?> get props => [
    cells,
    nextPrayerIndex,
    dateKey,
    hijriDateLabel,
    weekdayLabel,
    localeCode,
    isFriday,
  ];
}
