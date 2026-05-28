import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/ahadith/data/datasources/local/hadith_bookmark_local_data_source.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith_bookmark.dart';

class _MockBox extends Mock implements Box<List> {}

void main() {
  late _MockBox box;
  late HadithBookmarkLocalDataSource sut;

  setUp(() {
    box = _MockBox();
    sut = HadithBookmarkLocalDataSource(box: box);
  });

  group('getAll', () {
    test('returns empty set when box is empty', () {
      when(() => box.get('all')).thenReturn(null);

      expect(sut.getAll(), isEmpty);
    });

    test('parses stored entries into HadithBookmark set', () {
      when(() => box.get('all')).thenReturn(['bukhari:42', 'muslim:1']);

      final result = sut.getAll();

      expect(result, {
        const HadithBookmark(bookSlug: 'bukhari', hadithNumber: 42),
        const HadithBookmark(bookSlug: 'muslim', hadithNumber: 1),
      });
    });

    test('skips malformed entries', () {
      when(() => box.get('all'))
          .thenReturn(['bukhari:42', 'garbage', 'muslim:abc', 42]);

      expect(sut.getAll(), {
        const HadithBookmark(bookSlug: 'bukhari', hadithNumber: 42),
      });
    });
  });

  group('toggle', () {
    test('adds when absent and returns true', () async {
      when(() => box.get('all')).thenReturn(<String>[]);
      when(() => box.put('all', any<List<String>>())).thenAnswer((_) async {});

      final added = await sut.toggle(
        const HadithBookmark(bookSlug: 'bukhari', hadithNumber: 42),
      );

      expect(added, isTrue);
      verify(() => box.put('all', ['bukhari:42'])).called(1);
    });

    test('removes when present and returns false', () async {
      when(() => box.get('all')).thenReturn(['bukhari:42', 'muslim:1']);
      when(() => box.put('all', any<List<String>>())).thenAnswer((_) async {});

      final removed = await sut.toggle(
        const HadithBookmark(bookSlug: 'bukhari', hadithNumber: 42),
      );

      expect(removed, isFalse);
      final captured =
          verify(() => box.put('all', captureAny<List<String>>())).captured;
      expect(captured.single, ['muslim:1']);
    });

    test('different books with same hadith number are distinct', () {
      when(() => box.get('all')).thenReturn(['bukhari:1', 'muslim:1']);

      expect(sut.getAll().length, 2);
    });
  });
}
