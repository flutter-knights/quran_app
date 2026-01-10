import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

class HadithModel extends Hadith {
  HadithModel({
    required super.englishHadith,
    required super.arabicHadith,
    required super.englishNarrator,
    required super.id,
    required super.status,
    required super.bookId,
    required super.chapterId,
    super.chapter,
  });

  factory HadithModel.fromJson(
    Map<String, dynamic> json,
    Map<String, dynamic> chaptersMap,
  ) {
    final int cId = int.parse(json['chapterId'].toString());

    // Efficient lookup from the local JSON map
    final chapterData = chaptersMap[cId.toString()];

    Chapter? chapter;
    if (chapterData != null) {
      chapter = Chapter(
        id: chapterData['id'],
        chapterNumber: chapterData['chapterNumber'],
        chapterArabic: chapterData['chapterArabic'],
        chapterEnglish: chapterData['chapterEnglish'],
      );
    }

    return HadithModel(
      id: json['id'],
      englishHadith: json['hadithEnglish'] ?? '',
      arabicHadith: json['hadithArabic'] ?? '',
      englishNarrator: json['englishNarrator'] ?? '',
      chapterId: cId,
      bookId: json['book']['id'],
      status: _mapStatus(json['status']),
      chapter: chapter,
    );
  }

  static HadithStatus _mapStatus(String status) {
    switch (status.toLowerCase()) {
      case 'sahih':
        return HadithStatus.sahih;
      case 'hasan':
        return HadithStatus.hasan;
      default:
        return HadithStatus.daeef;
    }
  }
}
