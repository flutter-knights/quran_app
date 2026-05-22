import 'package:equatable/equatable.dart';

class PrayerCell extends Equatable {
  final String label;
  final String timeFormatted;

  const PrayerCell({required this.label, required this.timeFormatted});

  @override
  List<Object?> get props => [label, timeFormatted];
}
