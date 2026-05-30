import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/entities/download_progress.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';

abstract class AhadithRepository {
  Future<Either<Failure, HadithPage>> getAhadithPage(
    int pageNumber,
    String bookSlug,
  );
  Stream<DownloadProgress> downloadAllAhadith(String bookSlug);

  /// All chapters of [bookSlug] (with Arabic and English titles), available
  /// immediately from the bundled catalogue — no network needed.
  List<Chapter> getBookChapters(String bookSlug);

  /// The grades actually present in [bookSlug] (e.g. Sahih-only collections
  /// return just `{sahih}`), so the UI never offers a status that yields no
  /// results.
  Set<HadithStatus> getBookStatuses(String bookSlug);

  /// A page filtered server-side by [status] and/or [chapterId], for online
  /// (non-downloaded) browsing so the user isn't paged through the whole book
  /// to find matches. Not cached — filtered pages aren't full book pages.
  Future<Either<Failure, HadithPage>> getFilteredAhadithPage({
    required int pageNumber,
    required String bookSlug,
    HadithStatus? status,
    int? chapterId,
  });

  /// Returns the next hadith after [currentHadithNumber] within [bookSlug],
  /// or `Right(null)` when no further hadith exists.
  Future<Either<Failure, Hadith?>> getNextHadith({
    required String bookSlug,
    required String currentHadithNumber,
  });

  /// Returns the hadith before [currentHadithNumber] within [bookSlug],
  /// or `Right(null)` when [currentHadithNumber] is the first one.
  Future<Either<Failure, Hadith?>> getPreviousHadith({
    required String bookSlug,
    required String currentHadithNumber,
  });

  /// Fetches a single hadith by its number (used to open a bookmarked hadith),
  /// decorated with its chapter. `Right(null)` when no such hadith exists.
  Future<Either<Failure, Hadith?>> getHadithByNumber({
    required String bookSlug,
    required String hadithNumber,
  });
}
