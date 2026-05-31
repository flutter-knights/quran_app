// test/core/arabic_normalizer_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/helper%20functions/arabic_normalizer.dart';

void main() {
  group('normalizeArabic', () {
    test('strips tashkil (harakat)', () {
      expect(normalizeArabic('مُحَمَّدٌ'), 'محمد');
    });
    test('unifies alef forms and keeps only word-initial alef', () {
      expect(normalizeArabic('أحمد'), 'احمد');
      expect(normalizeArabic('إيمان'), 'ايمن'); // medial alef dropped
      expect(normalizeArabic('آدم'), 'ادم');
      expect(normalizeArabic('ٱلرَّحْمَـٰنِ'), 'الرحمن');
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
    test('is alef-tolerant: plene and conventional spellings collapse equally', () {
      expect(normalizeArabic('الرحمان'), 'الرحمن');
      expect(normalizeArabic('الرحمن'), 'الرحمن');
      expect(normalizeArabic('العالمين'), 'العلمين');
      expect(normalizeArabic('العلمين'), 'العلمين');
    });
  });
}
