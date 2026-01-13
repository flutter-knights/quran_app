import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';

class ChapterModel extends Chapter {
  ChapterModel({
    required super.id,
    required super.chapterNumber,
    required super.chapterArabic,
    required super.chapterEnglish,
  });

  factory ChapterModel.fromJson(Map<String, dynamic> json) {
    return ChapterModel(
      id: json['id'],
      chapterNumber: json['chapterNumber'],
      chapterArabic: json['chapterArabic'],
      chapterEnglish: json['chapterEnglish'],
    );
  }
}
