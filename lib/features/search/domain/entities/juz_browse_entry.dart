import 'package:equatable/equatable.dart';

class JuzBrowseEntry extends Equatable {
  final int number; // 1..30
  final int firstPage;
  final String firstSurahArabicName;
  final String lastSurahArabicName;
  const JuzBrowseEntry({
    required this.number,
    required this.firstPage,
    required this.firstSurahArabicName,
    required this.lastSurahArabicName,
  });

  @override
  List<Object?> get props =>
      [number, firstPage, firstSurahArabicName, lastSurahArabicName];
}
