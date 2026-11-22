import 'package:equatable/equatable.dart';

class Tafsir extends Equatable {
  const Tafsir({
    required this.surah,
    required this.ayah,
    required this.text,
    this.book = 'muyassar',
  });

  final int surah;
  final int ayah;
  final String text;
  final String book;

  @override
  List<Object?> get props => [surah, ayah, text, book];
}
