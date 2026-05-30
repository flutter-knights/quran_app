import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

abstract class DailyHadithRepository {
  /// Resolves the deterministic "Hadith of the Day" for [date] (UTC-based),
  /// serving a cached copy when available so it stays offline and stable
  /// within the day.
  Future<Either<Failure, ({Hadith hadith, String bookSlug})>> getDailyHadith(
    DateTime date,
  );
}
