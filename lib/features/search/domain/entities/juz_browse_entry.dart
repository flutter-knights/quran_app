import 'package:equatable/equatable.dart';

class JuzBrowseEntry extends Equatable {
  final int number; // 1..30
  final int firstPage;
  final int firstSurah;
  final int lastSurah;
  const JuzBrowseEntry({
    required this.number,
    required this.firstPage,
    required this.firstSurah,
    required this.lastSurah,
  });

  @override
  List<Object?> get props => [number, firstPage, firstSurah, lastSurah];
}
