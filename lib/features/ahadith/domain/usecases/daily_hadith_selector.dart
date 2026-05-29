import 'dart:math';

import 'package:quran_app/core/constants/hadith_constants.dart';

/// A deterministic (bookSlug, hadithNumber) pick for a given day.
class DailyHadithSelection {
  const DailyHadithSelection({
    required this.bookSlug,
    required this.hadithNumber,
  });

  final String bookSlug;
  final int hadithNumber;
}

/// Picks the "Hadith of the Day" purely from the date, so every device that
/// shares the same UTC day resolves to the same hadith — no server needed.
///
/// Draws only from the two Sahih collections for quality. Uses a self-contained
/// FNV-1a hash (not [String.hashCode], which isn't guaranteed stable across
/// Dart versions) so the seed — and therefore the pick — is reproducible
/// everywhere.
class DailyHadithSelector {
  static const List<String> books = ['sahih-bukhari', 'sahih-muslim'];

  /// UTC `YYYY-MM-DD` key for [date].
  static String dateKey(DateTime date) {
    final utc = date.toUtc();
    final m = utc.month.toString().padLeft(2, '0');
    final d = utc.day.toString().padLeft(2, '0');
    return '${utc.year}-$m-$d';
  }

  static int _seed(String key, int attempt) {
    // FNV-1a 32-bit over the date key, offset by the retry attempt.
    int hash = 0x811c9dc5;
    for (final code in key.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0xFFFFFFFF;
    }
    return (hash + attempt) & 0xFFFFFFFF;
  }

  /// Deterministic pick for [date]. [attempt] lets the caller re-roll
  /// reproducibly when a picked number doesn't resolve to a real hadith.
  static DailyHadithSelection select(DateTime date, {int attempt = 0}) {
    final rng = Random(_seed(dateKey(date), attempt));
    final book = books[rng.nextInt(books.length)];
    final count = HadithPagination.hadithCount(book);
    final number = count > 0 ? rng.nextInt(count) + 1 : 1;
    return DailyHadithSelection(bookSlug: book, hadithNumber: number);
  }
}
