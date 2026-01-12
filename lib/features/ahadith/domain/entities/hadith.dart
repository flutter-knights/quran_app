import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';

enum HadithStatus { sahih, hasan, daeef }

class Hadith {
  final int hadithNumber;
  final String englishHadith;
  final String arabicHadith;
  final String englishNarrator;
  final String englishHeader;
  final String arabicHeader;
  final HadithStatus status;
  final int chapterId;
  final Chapter? chapter;

  Hadith({
    required this.englishHadith,
    required this.arabicHadith,
    required this.englishNarrator,

    required this.status,
    required this.chapterId,
    this.chapter,
    required this.englishHeader,
    required this.arabicHeader,
    required this.hadithNumber,
  });
  Hadith copyWith({Chapter? chapter}) {
    return Hadith(
      englishHadith: englishHadith,
      arabicHadith: arabicHadith,
      englishNarrator: englishNarrator,
      chapterId: chapterId,
      status: status,
      arabicHeader: arabicHeader,
      englishHeader: englishHeader,
      chapter: chapter ?? this.chapter,
      hadithNumber: hadithNumber,
    );
  }
}
