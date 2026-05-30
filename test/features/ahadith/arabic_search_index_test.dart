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
}
