import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/quran_playback/domain/services/quran_meta_service.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/surah/presentation/utils/menu_query.dart';

void main() {
  test('blank and unknown queries resolve to none', () {
    for (final q in ['', '   ', 'xyz']) {
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
    for (final q in ['0', '605', '٦٠٥']) {
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
