import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/search/data/quran_browse_service_impl.dart';

void main() {
  final sut = QuranBrowseServiceImpl();

  test('juzʼ 1 starts on page 1', () {
    expect(sut.firstPageOfJuz(1), 1);
  });

  test('juzʼ first pages increase monotonically', () {
    expect(sut.firstPageOfJuz(2), greaterThan(sut.firstPageOfJuz(1)));
    expect(sut.firstPageOfJuz(30), greaterThan(sut.firstPageOfJuz(29)));
  });

  test('produces 30 browse entries with non-empty surah spans', () {
    final entries = sut.juzEntries();
    expect(entries, hasLength(30));
    expect(entries.first.number, 1);
    expect(entries.first.firstPage, 1);
    expect(entries.first.firstSurahArabicName, isNotEmpty);
    expect(entries.last.number, 30);
  });
}
