import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

class HadithModel extends Hadith {
  HadithModel({
    required super.englishHadith,
    required super.arabicHadith,
    required super.englishNarrator,
    required super.hadithNumber,
    required super.status,
    required super.englishHeader,
    required super.arabicHeader,
    required super.chapterId,
    super.chapter,
  });

  factory HadithModel.fromJson(Map<String, dynamic> json) {
    return HadithModel(
      hadithNumber: int.parse(json['hadithNumber']) ,
      englishHadith: json['hadithEnglish'] ?? '',
      arabicHadith: json['hadithArabic'] ?? '',
      englishHeader: json['headingEnglish'] ?? '',
      arabicHeader: json['headingArabic'] ?? '',
      englishNarrator: json['englishNarrator'] ?? '',
      chapterId: json['chapter']['id'],
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
