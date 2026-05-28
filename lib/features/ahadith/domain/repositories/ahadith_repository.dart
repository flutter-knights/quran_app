import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/domain/entities/download_progress.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_page.dart';

abstract class AhadithRepository {
  Future<Either<Failure, HadithPage>> getAhadithPage(
    int pageNumber,
    String bookSlug,
  );
  Stream<DownloadProgress> downloadAllAhadith(String bookSlug);

  /// Returns the next hadith after [currentHadithNumber] within [bookSlug],
  /// or `Right(null)` when no further hadith exists.
  Future<Either<Failure, Hadith?>> getNextHadith({
    required String bookSlug,
    required int currentHadithNumber,
  });
}
