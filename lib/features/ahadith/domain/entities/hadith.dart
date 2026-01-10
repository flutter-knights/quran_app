import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';

enum HadithStatus { sahih, hasan, daeef }

class Hadith {
  final String englishHadith;
  final String arabicHadith;
  final String englishNarrator;
  final int id;
  final HadithStatus status;
  final int bookId;
  final int chapterId;
  final Chapter? chapter; // The new addition

  Hadith({
    required this.englishHadith,
    required this.arabicHadith,
    required this.englishNarrator,
    required this.id,
    required this.status,
    required this.bookId,
    required this.chapterId,
    this.chapter,
  });
}
