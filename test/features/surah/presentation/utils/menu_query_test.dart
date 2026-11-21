import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/quran_playback/domain/services/quran_meta_service.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/surah/presentation/utils/menu_query.dart';

void main() {
  test('blank and unknown queries resolve to none', () {
    for (final q in ['', '   ', 'xyz', 'ـ', 'َ', 'ـَـ']) {
      expect(resolveMenuQuery(q), const MenuQueryNone(), reason: q);
    }
  });

  test('page numbers in any digit set resolve to the page', () {
    for (final q in ['582', '٥٨٢', '٥8٢', ' 582 ']) {
      expect(
        resolveMenuQuery(q),
        const MenuQueryTarget(page: 582, surah: 78, juz: 30),
        reason: q,
      );
    }
  });

  test('numbers outside 1 to 604 are out of range', () {
    for (final q in ['0', '605', '٦٠٥', '-3', '99999999999999999999']) {
      expect(resolveMenuQuery(q), const MenuQueryOutOfRange(), reason: q);
    }
  });

  test('surah names resolve with or without hamza and in Latin', () {
    expect(
      resolveMenuQuery('الكهف'),
      const MenuQueryTarget(page: 293, surah: 18, juz: 15),
    );
    final isra = resolveMenuQuery('الاسراء') as MenuQueryTarget;
    expect(isra.surah, 17);
    expect(isra.page, quran.getPageNumber(17, 1));
    expect((resolveMenuQuery('kahf') as MenuQueryTarget).surah, 18);
  });

  test('bare surah names without the article resolve', () {
    const expected = {'انعام': 6, 'اسراء': 17, 'إخلاص': 112, 'كهف': 18};
    for (final e in expected.entries) {
      expect(
        (resolveMenuQuery(e.key) as MenuQueryTarget).surah,
        e.value,
        reason: e.key,
      );
    }
  });

  test('Latin names ignore case, punctuation and spacing', () {
    for (final q in ['Al-Kahf', 'al kahf', 'ALKAHF']) {
      expect((resolveMenuQuery(q) as MenuQueryTarget).surah, 18, reason: q);
    }
  });

  test('the juz matches the running head on mid-page juz starts', () {
    final meta = QuranMetaServiceImpl(pageService: QuranPageServiceImpl());
    for (final p in [62, 121, 201, 502]) {
      expect(
        (resolveMenuQuery('$p') as MenuQueryTarget).juz,
        meta.getPageMeta(p).juz,
        reason: '$p',
      );
    }
  });
}
