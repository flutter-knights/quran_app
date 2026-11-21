import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/data/models/mushaf_page_model.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';
import 'package:quran_app/features/surah/presentation/utils/page_bounds.dart';

List<AyahBoundEntity> bounds(int p) => MushafPageModel.fromJson(
  jsonDecode(
    File(
      'assets/mushaf/bounds/page_${p.toString().padLeft(3, '0')}.json',
    ).readAsStringSync(),
  ),
).ayahs;

AyahIdentifier id(int s, int a) => AyahIdentifier(surah: s, ayah: a);

AyahBoundEntity bound(int s, int a, int lines) => AyahBoundEntity(
  ayah: id(s, a),
  lines: List.generate(
    lines,
    (_) => const NormalizedRect(x: 0, y: 0, w: 1, h: 0.1),
  ),
);

void main() {
  group('resolveRunningSurah', () {
    test('opened surah decides p.293 when it is on the page', () {
      expect(resolveRunningSurah(ayahs: bounds(293), openedSurah: 18), 18);
    });

    test('p.604 goes to 114 by line count', () {
      expect(resolveRunningSurah(ayahs: bounds(604)), 114);
    });

    test('p.106 goes to 5', () {
      expect(resolveRunningSurah(ayahs: bounds(106)), 5);
    });

    test('p.76 goes to 3', () {
      expect(resolveRunningSurah(ayahs: bounds(76)), 3);
    });

    test('p.207 goes to 9', () {
      expect(resolveRunningSurah(ayahs: bounds(207)), 9);
    });

    test('p.293 without an opened surah goes to 17', () {
      expect(resolveRunningSurah(ayahs: bounds(293)), 17);
    });

    test('a selected ayah on the page wins', () {
      expect(resolveRunningSurah(ayahs: bounds(106), selected: id(4, 176)), 4);
    });

    test('a playing ayah on the page wins', () {
      expect(resolveRunningSurah(ayahs: bounds(106), playing: id(4, 176)), 4);
    });

    test('a selection and an opened surah off the page fall through', () {
      expect(
        resolveRunningSurah(
          ayahs: bounds(106),
          selected: id(2, 1),
          openedSurah: 9,
        ),
        5,
      );
    });

    test('a selected banner counts as its ayah 1', () {
      expect(resolveRunningSurah(ayahs: bounds(293), selected: id(18, 0)), 18);
    });

    test('a playing banner counts as its ayah 1', () {
      expect(resolveRunningSurah(ayahs: bounds(293), playing: id(18, 0)), 18);
    });

    test('a tie goes to the lower surah', () {
      expect(resolveRunningSurah(ayahs: [bound(8, 1, 3), bound(7, 1, 3)]), 7);
    });

    test('no ayahs returns null', () {
      expect(resolveRunningSurah(ayahs: const []), isNull);
    });

    test('only banner bounds return null', () {
      expect(resolveRunningSurah(ayahs: [bound(2, 0, 2)]), isNull);
    });
  });

  group('pagePlaybackRange', () {
    test('p.76', () {
      final r = pagePlaybackRange(bounds(76))!;
      expect((r.start, r.end), (id(3, 195), id(3, 200)));
    });

    test('p.106 crosses a surah', () {
      final r = pagePlaybackRange(bounds(106))!;
      expect((r.start, r.end), (id(4, 176), id(5, 2)));
    });

    test('p.207', () {
      final r = pagePlaybackRange(bounds(207))!;
      expect((r.start, r.end), (id(9, 123), id(9, 129)));
    });

    test('p.604', () {
      final r = pagePlaybackRange(bounds(604))!;
      expect((r.start, r.end), (id(112, 1), id(114, 6)));
    });

    test('p.2 skips the 2:0 banner', () {
      final r = pagePlaybackRange(bounds(2))!;
      expect((r.start, r.end), (id(2, 1), id(2, 5)));
    });

    test('empty returns null', () {
      expect(pagePlaybackRange(const []), isNull);
    });
  });
}
