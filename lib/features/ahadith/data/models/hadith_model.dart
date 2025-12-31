
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';

class HadithModel extends Hadith {
  HadithModel({
    required super.englishHadith,
    required super.arabicHadith,
    required super.englishNarrator,
    required super.id,
    required super.chapter,
    required super.status,
    required super.bookId,
    required super.chapterId,
  });

  factory HadithModel.fromJson(Map<String, dynamic> json) {
    return HadithModel(
      id: json['id'],
      englishHadith: json['hadithEnglish'] ?? '',
      arabicHadith: json['hadithArabic'] ?? '',
      englishNarrator: json['englishNarrator'] ?? '',
      chapter: int.parse(json['chapterId'].toString()),
      chapterId: int.parse(json['chapterId'].toString()),
      bookId: json['book']['id'],
      status: _mapStatus(json['status']),
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



