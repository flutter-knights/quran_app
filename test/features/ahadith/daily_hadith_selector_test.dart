import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/hadith_constants.dart';
import 'package:quran_app/features/ahadith/domain/usecases/daily_hadith_selector.dart';

void main() {
  test('same UTC day yields the same pick regardless of time of day', () {
    final morning = DateTime.utc(2026, 5, 29, 1, 0);
    final night = DateTime.utc(2026, 5, 29, 23, 30);
    final a = DailyHadithSelector.select(morning);
    final b = DailyHadithSelector.select(night);
    expect(a.bookSlug, b.bookSlug);
    expect(a.hadithNumber, b.hadithNumber);
  });

  test('dateKey normalizes to UTC YYYY-MM-DD', () {
    expect(
      DailyHadithSelector.dateKey(DateTime.utc(2026, 1, 5, 12)),
      '2026-01-05',
    );
  });

  test('selection is reproducible across calls (deterministic)', () {
    final date = DateTime.utc(2026, 12, 31);
    final a = DailyHadithSelector.select(date);
    final b = DailyHadithSelector.select(date);
    expect(a.bookSlug, b.bookSlug);
    expect(a.hadithNumber, b.hadithNumber);
  });

  test('always picks from the Sahih collections within a valid range', () {
    for (var day = 1; day <= 28; day++) {
      final s = DailyHadithSelector.select(DateTime.utc(2026, 3, day));
      expect(DailyHadithSelector.books, contains(s.bookSlug));
      expect(s.hadithNumber, greaterThanOrEqualTo(1));
      expect(
        s.hadithNumber,
        lessThanOrEqualTo(HadithPagination.hadithCount(s.bookSlug)),
      );
    }
  });

  test('different days produce variety (not all identical)', () {
    final picks = <String>{};
    for (var day = 1; day <= 28; day++) {
      final s = DailyHadithSelector.select(DateTime.utc(2026, 4, day));
      picks.add('${s.bookSlug}#${s.hadithNumber}');
    }
    // 28 deterministic picks should not collapse to a single value.
    expect(picks.length, greaterThan(20));
  });

  test('retry attempts reroll the selection', () {
    final date = DateTime.utc(2026, 6, 1);
    final picks = <String>{};
    for (var attempt = 0; attempt < 5; attempt++) {
      final s = DailyHadithSelector.select(date, attempt: attempt);
      picks.add('${s.bookSlug}#${s.hadithNumber}');
    }
    expect(picks.length, greaterThan(1));
  });
}
