import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/page_description.dart';

void main() {
  test('page 1 (Al-Fatiha) — English', () {
    // page 1 = basmala marker + Al-Fatiha 1–7; basmala is skipped.
    expect(describePage(1, localeCode: 'en'), 'Al Fatiha 1–7');
  });

  test('page 1 — Arabic uses Arabic-Indic numerals', () {
    expect(describePage(1, localeCode: 'ar'), contains('١'));
  });

  test('last page (604) joins multiple surahs', () {
    // 604 = Al-Ikhlas, Al-Falaq, An-Nas.
    final d = describePage(604, localeCode: 'en');
    expect(d.split(',').length, 3);
  });
}
