import 'package:equatable/equatable.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_cell.dart';

class PrayerStripState extends Equatable {
  final List<PrayerCell> cells;
  final int nextPrayerIndex;
  final String hijriDateLabel;
  final String weekdayLabel;
  final String localeCode;
  final bool isFriday;

  /// ARGB color (e.g. `0xFF2E5244`) for the next-prayer pill, sourced from the
  /// app's selected palette. `null` lets the native renderer fall back to its
  /// own `strip_accent` resource (backward-compatible default).
  final int? accentColor;

  const PrayerStripState({
    required this.cells,
    required this.nextPrayerIndex,
    required this.hijriDateLabel,
    required this.weekdayLabel,
    required this.localeCode,
    required this.isFriday,
    this.accentColor,
  });

  PrayerStripState copyWith({
    List<PrayerCell>? cells,
    int? nextPrayerIndex,
    String? hijriDateLabel,
    String? weekdayLabel,
    String? localeCode,
    bool? isFriday,
    int? accentColor,
  }) {
    return PrayerStripState(
      cells: cells ?? this.cells,
      nextPrayerIndex: nextPrayerIndex ?? this.nextPrayerIndex,
      hijriDateLabel: hijriDateLabel ?? this.hijriDateLabel,
      weekdayLabel: weekdayLabel ?? this.weekdayLabel,
      localeCode: localeCode ?? this.localeCode,
      isFriday: isFriday ?? this.isFriday,
      accentColor: accentColor ?? this.accentColor,
    );
  }

  Map<String, Object> toJson() => {
        'cells': cells
            .map((c) => {'label': c.label, 'time': c.timeFormatted})
            .toList(),
        'nextPrayerIndex': nextPrayerIndex,
        'hijriDateLabel': hijriDateLabel,
        'weekdayLabel': weekdayLabel,
        'localeCode': localeCode,
        'isFriday': isFriday,
        // Sent as a `#AARRGGBB` hex string so the native side parses it with
        // Color.parseColor — avoids signed-int / Long ambiguity across the
        // MethodChannel for ARGB values above 0x7FFFFFFF.
        if (accentColor != null) 'accentColor': _toHex(accentColor!),
      };

  factory PrayerStripState.fromJson(Map<String, Object?> json) {
    final rawCells = (json['cells'] as List).cast<Map<String, Object?>>();
    final rawAccent = json['accentColor'] as String?;
    return PrayerStripState(
      cells: rawCells
          .map((m) => PrayerCell(
                label: m['label'] as String,
                timeFormatted: m['time'] as String,
              ))
          .toList(),
      nextPrayerIndex: json['nextPrayerIndex'] as int,
      hijriDateLabel: json['hijriDateLabel'] as String,
      weekdayLabel: (json['weekdayLabel'] as String?) ?? '',
      localeCode: json['localeCode'] as String,
      isFriday: json['isFriday'] as bool,
      accentColor: rawAccent == null
          ? null
          : int.parse(rawAccent.substring(1), radix: 16),
    );
  }

  static String _toHex(int argb) =>
      '#${argb.toRadixString(16).padLeft(8, '0').toUpperCase()}';

  @override
  List<Object?> get props => [
        cells,
        nextPrayerIndex,
        hijriDateLabel,
        weekdayLabel,
        localeCode,
        isFriday,
        accentColor,
      ];
}
