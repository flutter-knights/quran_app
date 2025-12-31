enum HadithStatus { sahih, hasan, daeef }

class Hadith {
  final String englishHadith;
  final String arabicHadith;
  final String englishNarrator;
  final int id;
  final int chapter;
  final HadithStatus status;
  final int bookId;
  final int chapterId;

  Hadith({
    required this.englishHadith,
    required this.arabicHadith,
    required this.englishNarrator,
    required this.id,
    required this.chapter,
    required this.status,
    required this.bookId,
    required this.chapterId,
  });
}
