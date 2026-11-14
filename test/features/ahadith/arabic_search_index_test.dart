import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/ahadith_arabic_search_local_data_source.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

void main() {
  final index = <String, ArabicIndexEntry>{
    '1': const ArabicIndexEntry(text: 'الصلاه فرض', chapterId: 5, status: HadithStatus.sahih),
    '2': const ArabicIndexEntry(text: 'الصلاه سنه', chapterId: 9, status: HadithStatus.sahih),
    '3': const ArabicIndexEntry(text: 'الصلاه فرض', chapterId: 5, status: HadithStatus.daeef),
  };

  test('filters by chapterId before capping', () {
    final result = searchIndexEntries(index, 'الصلاه', chapterId: 5, limit: 100);
    expect(result.toSet(), {'1', '3'});
  });

  test('filters by status', () {
    final result = searchIndexEntries(index, 'الصلاه', status: HadithStatus.daeef, limit: 100);
    expect(result, ['3']);
  });

  test('caps results after filtering', () {
    final result = searchIndexEntries(index, 'الصلاه', limit: 2);
    expect(result.length, 2);
  });

  test('parseIndexValue tolerates an old bare-string entry', () {
    final entry = parseIndexValue('نص قديم');
    expect(entry.text, 'نص قديم');
    expect(entry.chapterId, isNull);
    expect(entry.status, isNull);
  });

  test('parseIndexValue parses a well-formed map entry', () {
    final entry = parseIndexValue({'t': 'الصلاه فرض', 'c': 5, 's': 'sahih'});
    expect(entry.text, 'الصلاه فرض');
    expect(entry.chapterId, 5);
    expect(entry.status, HadithStatus.sahih);
  });

  test('parseIndexValue tolerates missing c/s keys in map', () {
    final entry = parseIndexValue({'t': 'نص'});
    expect(entry.chapterId, isNull);
    expect(entry.status, isNull);
  });

  test('parseIndexValue returns null status for unknown grade name', () {
    final entry = parseIndexValue({'t': 'نص', 's': 'mawdu'});
    expect(entry.status, isNull);
  });

  test('filter-before-cap: a chapter match after the cap boundary is not lost', () {
    // Entries ordered ch9, ch9, ch5. A cap-before-filter (limit:2) would drop 'c'.
    final orderedIndex = <String, ArabicIndexEntry>{
      'a': const ArabicIndexEntry(text: 'الصلاه', chapterId: 9, status: HadithStatus.sahih),
      'b': const ArabicIndexEntry(text: 'الصلاه', chapterId: 9, status: HadithStatus.sahih),
      'c': const ArabicIndexEntry(text: 'الصلاه', chapterId: 5, status: HadithStatus.sahih),
    };
    final result = searchIndexEntries(orderedIndex, 'الصلاه', chapterId: 5, limit: 2);
    expect(result, ['c']); // would be [] if the cap fired before the filter
  });
}
