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

  String get body {
    final trimmed = text.trimLeft();
    if (surah != 1 || ayah != 1 || !trimmed.startsWith('سورة الفاتحة')) {
      return text;
    }
    final stop = trimmed.indexOf('. ');
    return stop == -1 ? text : trimmed.substring(stop + 2).trim();
  }

  @override
  List<Object?> get props => [surah, ayah, text, book];
}
