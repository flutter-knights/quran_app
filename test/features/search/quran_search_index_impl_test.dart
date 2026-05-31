// test/features/search/quran_search_index_impl_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/helper%20functions/arabic_normalizer.dart';
import 'package:quran_app/features/search/data/quran_search_index_impl.dart';

void main() {
  final index = QuranSearchIndexImpl.build();

  test('matches a surah by Arabic name fragment', () {
    final r = index.searchSurahNames(normalizeArabic('فاتح'));
    expect(r.any((s) => s.number == 1), isTrue);
  });

  test('matches a surah by English name fragment', () {
    final r = index.searchSurahNames(normalizeArabic('opening'));
    expect(r.any((s) => s.number == 1), isTrue);
  });

  test('matches a surah by its number', () {
    final r = index.searchSurahNames(normalizeArabic('114'));
    expect(r.any((s) => s.number == 114), isTrue);
  });

  test('matches ayah text present in the corpus (Al-Fatiha basmala)', () {
    final r = index.searchAyahText(normalizeArabic('الرحمان'));
    expect(r.results, isNotEmpty);
    expect(r.total, greaterThan(0));
    final first = r.results.firstWhere((a) => a.surah == 1 && a.ayah == 1);
    expect(first.page, 1);
  });

  test('caps results at limit but reports the real total', () {
    final r = index.searchAyahText(normalizeArabic('الله'), limit: 5);
    expect(r.results.length, lessThanOrEqualTo(5));
    expect(r.total, greaterThanOrEqualTo(r.results.length));
  });
}
