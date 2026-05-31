// test/core/arabic_normalizer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/helper%20functions/arabic_normalizer.dart';

void main() {
  group('normalizeArabic', () {
    test('strips tashkil (harakat)', () {
      expect(normalizeArabic('مُحَمَّدٌ'), 'محمد');
    });
    test('unifies alef forms أ إ آ ٱ to ا', () {
      expect(normalizeArabic('أحمد'), 'احمد');
      expect(normalizeArabic('إيمان'), 'ايمان');
      expect(normalizeArabic('آدم'), 'ادم');
    });
    test('maps ى to ي and ة to ه', () {
      expect(normalizeArabic('إلى'), 'الي');
      expect(normalizeArabic('سورة'), 'سوره');
    });
    test('removes tatweel', () {
      expect(normalizeArabic('الـلـه'), 'الله');
    });
    test('lowercases and trims latin, collapses inner whitespace', () {
      expect(normalizeArabic('  Al-Fatiha '), 'al-fatiha');
      expect(normalizeArabic('a   b'), 'a b');
    });
    test('empty stays empty', () {
      expect(normalizeArabic('   '), '');
    });
  });
}
