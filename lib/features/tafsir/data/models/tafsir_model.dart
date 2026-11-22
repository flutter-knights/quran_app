import 'package:equatable/equatable.dart';

import '../../domain/entities/tafsir.dart';

class TafsirModel extends Equatable {
  const TafsirModel({
    required this.surah,
    required this.ayah,
    required this.text,
  });

  factory TafsirModel.fromJson(Map item) {
    final surah = item['surah'];
    final number = surah is Map ? surah['number'] : null;
    final ayah = item['numberInSurah'];
    final text = item['text'];
    if (number is! int || ayah is! int || text is! String) {
      throw const FormatException('Malformed tafsir ayah');
    }
    return TafsirModel(surah: number, ayah: ayah, text: text);
  }

  final int surah;
  final int ayah;
  final String text;

  @override
  List<Object?> get props => [surah, ayah, text];

  Tafsir toEntity() => Tafsir(surah: surah, ayah: ayah, text: text);
}
