import 'package:equatable/equatable.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';

class PrayerStripState extends Equatable {
  final List<PrayerCell> cells;
  final int nextPrayerIndex;
  final String hijriDateLabel;
  final String localeCode;
  final bool isFriday;

  const PrayerStripState({
    required this.cells,
    required this.nextPrayerIndex,
    required this.hijriDateLabel,
    required this.localeCode,
    required this.isFriday,
  });

  PrayerStripState copyWith({
    List<PrayerCell>? cells,
    int? nextPrayerIndex,
    String? hijriDateLabel,
    String? localeCode,
    bool? isFriday,
  }) {
    return PrayerStripState(
      cells: cells ?? this.cells,
      nextPrayerIndex: nextPrayerIndex ?? this.nextPrayerIndex,
      hijriDateLabel: hijriDateLabel ?? this.hijriDateLabel,
      localeCode: localeCode ?? this.localeCode,
      isFriday: isFriday ?? this.isFriday,
    );
  }

  Map<String, Object> toJson() => {
        'cells': cells
            .map((c) => {'label': c.label, 'time': c.timeFormatted})
            .toList(),
        'nextPrayerIndex': nextPrayerIndex,
        'hijriDateLabel': hijriDateLabel,
        'localeCode': localeCode,
        'isFriday': isFriday,
      };

  factory PrayerStripState.fromJson(Map<String, Object?> json) {
    final rawCells = (json['cells'] as List).cast<Map<String, Object?>>();
    return PrayerStripState(
      cells: rawCells
          .map((m) => PrayerCell(
                label: m['label'] as String,
                timeFormatted: m['time'] as String,
              ))
          .toList(),
      nextPrayerIndex: json['nextPrayerIndex'] as int,
      hijriDateLabel: json['hijriDateLabel'] as String,
      localeCode: json['localeCode'] as String,
      isFriday: json['isFriday'] as bool,
    );
  }

  @override
  List<Object?> get props =>
      [cells, nextPrayerIndex, hijriDateLabel, localeCode, isFriday];
}
