import 'package:dartz/dartz.dart';
import 'package:flutter/foundation.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/daily_hadith_local_data_source.dart';
import 'package:quran_app/features/ahadith/data/datasources/remote/ahadith_remote_data_source.dart';
import 'package:quran_app/features/ahadith/data/models/hadith_hive_model.dart';
import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';
import 'package:quran_app/features/ahadith/domain/repositories/daily_hadith_repository.dart';
import 'package:quran_app/features/ahadith/domain/usecases/daily_hadith_selector.dart';

class DailyHadithRepositoryImpl implements DailyHadithRepository {
  DailyHadithRepositoryImpl({
    required this.remote,
    required this.local,
    required this.ahadithRepository,
  });

  final AhadithRemoteDataSource remote;
  final DailyHadithLocalDataSource local;

  /// Used to attach the bundled chapter (Arabic + English) to the fetched
  /// hadith, so the daily hadith shows its chapter like the in-list view does.
  final AhadithRepository ahadithRepository;

  /// How many deterministic re-rolls to try when a picked number doesn't
  /// resolve to a real hadith (sparse numbering). Each attempt is reproducible.
  static const int _maxAttempts = 5;

  @override
  Future<Either<Failure, ({Hadith hadith, String bookSlug})>> getDailyHadith(
    DateTime date,
  ) async {
    final key = DailyHadithSelector.dateKey(date);

    // Everything is wrapped: a cache read, parse, decoration, or network error
    // must degrade to a hidden card, never crash the home screen.
    try {
      final cached = local.get(key);
      if (cached != null) {
        return Right((
          hadith: _withChapter(cached.toEntity(), cached.bookSlug),
          bookSlug: cached.bookSlug,
        ));
      }

      for (var attempt = 0; attempt < _maxAttempts; attempt++) {
        final selection = DailyHadithSelector.select(date, attempt: attempt);
        final results = await remote.getAhadithByNumbers(
          [selection.hadithNumber.toString()],
          selection.bookSlug,
        );
        if (results.isNotEmpty) {
          final hadith = results.first;
          await local.put(
            key,
            HadithHiveModel.fromEntity(hadith, 0, selection.bookSlug),
          );
          return Right((
            hadith: _withChapter(hadith, selection.bookSlug),
            bookSlug: selection.bookSlug,
          ));
        }
      }
      return left(const UnknownFailure('No daily hadith could be resolved.'));
    } catch (e, st) {
      debugPrint('[daily-hadith] failed: $e\n$st');
      return left(UnknownFailure(e.toString()));
    }
  }

  /// Attaches the bundled chapter matching the hadith's chapterId, so the daily
  /// hadith renders its chapter just like the paginated list (remote fetches
  /// only carry the chapterId, not the chapter titles).
  Hadith _withChapter(Hadith hadith, String bookSlug) {
    Chapter? chapter;
    for (final c in ahadithRepository.getBookChapters(bookSlug)) {
      if (c.id == hadith.chapterId) {
        chapter = c;
        break;
      }
    }
    if (chapter == null) return hadith;
    return hadith.copyWith(
      chapter: chapter,
      arabicNormalized: hadith.arabicHadithNormalized ?? hadith.arabicHadith,
    );
  }
}
