import 'package:equatable/equatable.dart';

class PrayerCell extends Equatable {
  final String label;
  final String timeFormatted;

  /// 24-hour minutes-from-midnight (`h*60+m`). Format-/locale-independent —
  /// the native side uses this for highlight + alarm scheduling so it never
  /// parses the localized [timeFormatted] string.
  final int minutes;

  final String nextLabel;

  const PrayerCell({
    required this.label,
    required this.timeFormatted,
    required this.minutes,
    this.nextLabel = '',
  });

  @override
  List<Object?> get props => [label, timeFormatted, minutes, nextLabel];
}
