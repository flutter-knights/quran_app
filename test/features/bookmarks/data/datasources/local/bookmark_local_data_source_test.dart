import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/bookmarks/data/datasources/local/bookmark_local_data_source.dart';

class _MockBox extends Mock implements Box<List> {}

void main() {
  late _MockBox box;
  late BookmarkLocalDataSource ds;

  setUp(() {
    box = _MockBox();
    ds = BookmarkLocalDataSource(box: box);
  });

  group('getAll', () {
    test('returns empty set when no entries stored', () {
      when(() => box.get('all')).thenReturn(null);

      final result = ds.getAll();

      expect(result, isEmpty);
    });

    test('parses stored entries into AyahIdentifier set', () {
      when(() => box.get('all')).thenReturn(['1:1', '2:255']);

      final result = ds.getAll();

      expect(result.length, 2);
      expect(result.any((a) => a.surah == 1 && a.ayah == 1), isTrue);
      expect(result.any((a) => a.surah == 2 && a.ayah == 255), isTrue);
    });

    test('skips malformed entries', () {
      when(() => box.get('all')).thenReturn(['1:1', 'garbage', '2:abc']);

      final result = ds.getAll();

      expect(result.length, 1);
    });
  });

  group('toggle', () {
    test('adds when absent, returns true', () async {
      when(() => box.get('all')).thenReturn(<String>[]);
      when(() => box.put('all', any<List<String>>()))
          .thenAnswer((_) async {});

      final added = await ds.toggle(surah: 2, ayah: 255);

      expect(added, isTrue);
      verify(() => box.put('all', ['2:255'])).called(1);
    });

    test('removes when present, returns false', () async {
      when(() => box.get('all')).thenReturn(['2:255', '1:1']);
      when(() => box.put('all', any<List<String>>()))
          .thenAnswer((_) async {});

      final added = await ds.toggle(surah: 2, ayah: 255);

      expect(added, isFalse);
      final captured =
          verify(() => box.put('all', captureAny<List<String>>())).captured;
      expect(captured.single, ['1:1']);
    });
  });
}
