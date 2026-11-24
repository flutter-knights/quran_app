import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/surah/presentation/utils/mushaf_grid.dart';

import '../../mushaf_bounds_fixture.dart';

const _pageTopSurahs = [
  4,
  10,
  22,
  23,
  24,
  26,
  27,
  32,
  33,
  37,
  38,
  45,
  47,
  53,
  60,
  64,
  65,
  80,
];

MushafLine _slot(int surah) {
  final start = quran.getPageNumber(surah, 1);
  return headerSlot(
    surah: surah,
    startPage: start,
    startPageBounds: boundsOf(start),
  );
}

void main() {
  test('grid constants match the generator', () {
    expect(mushafGridTop, closeTo(162.14, 1e-3));
    expect(mushafLineHeight, closeTo(169.41, 1e-2));
    expect(mushafColumnWidth, closeTo(1218.36, 1e-2));
  });

  test('2:282 fills grid lines 0 to 14', () {
    expect(linesOf(2, 282).map(gridLineOf), [for (var i = 0; i < 15; i++) i]);
  });

  test('the 18 page-top surahs take line 14 of the previous page', () {
    for (final surah in _pageTopSurahs) {
      expect(_slot(surah), (
        page: quran.getPageNumber(surah, 1) - 1,
        line: 14,
      ), reason: 'surah $surah');
    }
    expect(_slot(4), (page: 76, line: 14));
  });

  test('surahs 1 and 9 sit above ayah 1', () {
    expect(_slot(1), (page: 1, line: 0));
    expect(_slot(9), (page: 187, line: 0));
  });

  test('a start page without the surah fails with a StateError', () {
    expect(
      () => headerSlot(surah: 2, startPage: 1, startPageBounds: boundsOf(1)),
      throwsStateError,
    );
  });

  test('each header on page 602 belongs to its own surah', () {
    expect(_slot(106), (page: 602, line: 0));
    expect(_slot(107), (page: 602, line: 5));
    expect(_slot(108), (page: 602, line: 11));
  });

  test('every surah has a header slot in the grid', () {
    for (var surah = 1; surah <= 114; surah++) {
      final slot = _slot(surah);
      final start = quran.getPageNumber(surah, 1);
      expect(slot.line, inInclusiveRange(0, 14), reason: 'surah $surah');
      expect(
        slot.page,
        _pageTopSurahs.contains(surah) ? start - 1 : start,
        reason: 'surah $surah',
      );
    }
  });

  test('91:11 is clipped at the narrower rosette rect of 91:10', () {
    final pageRects = pageRectsOf(595);
    final edges = rowEdges(linesOf(91, 11).single, pageRects);
    expect(edges.right, closeTo(0.8657 * 1536, 0.5));
    expect(edges.leftOpen, isFalse);
    expect(edges.rightOpen, isFalse);

    final previous = rowEdges(linesOf(91, 10).last, pageRects);
    expect(previous.leftOpen, isFalse);
    expect(previous.rightOpen, isTrue);
  });

  test('a full line is open on both sides', () {
    final rect = linesOf(2, 282).firstWhere((r) => gridLineOf(r) == 5);
    final edges = rowEdges(rect, pageRectsOf(48));
    expect(edges.leftOpen, isTrue);
    expect(edges.rightOpen, isTrue);
    expect(edges.left, closeTo(0.1043 * 1536, 0.5));
  });

  test('rowSource pads open edges to whole pixels', () {
    final rect = linesOf(6, 31)[1];
    final edges = rowEdges(rect, pageRectsOf(131));
    expect(rowSource(rect, edges), const Rect.fromLTRB(112, 1017, 1425, 1186));
  });

  test('rowSource on line 0 ends at the rect bottom', () {
    final rect = linesOf(2, 282).first;
    final src = rowSource(rect, rowEdges(rect, pageRectsOf(48)));
    expect(src.top, 172);
    expect(src.bottom, 341);
  });

  test('lineInkSource spans the row edges and the band with a margin', () {
    final rect = linesOf(6, 31)[1];
    final edges = rowEdges(rect, pageRectsOf(131));
    expect(gridBand(gridLineOf(rect)), (top: 1009, bottom: 1178));
    expect(
      lineInkSource(rect, edges),
      const Rect.fromLTRB(112, 949, 1425, 1238),
    );
  });

  group('keepLineInk', () {
    const width = 60;
    const line = 1;
    final band = gridBand(line);
    final top = band.top - mushafInkMargin;
    final height = band.bottom + mushafInkMargin - top;
    final edgeTop = band.top - top;
    final edgeBottom = band.bottom - top;

    ByteData page(List<(int, int, int, int)> blobs) {
      final data = ByteData(width * height * 4);
      for (final (x0, y0, x1, y1) in blobs) {
        for (var y = y0; y < y1; y++) {
          for (var x = x0; x < x1; x++) {
            data.setUint8((y * width + x) * 4 + 3, 255);
          }
        }
      }
      return data;
    }

    int alphaAt(ByteData data, int x, int y) =>
        data.getUint8((y * width + x) * 4 + 3);

    test('keeps the line and clears the lines above and below', () {
      final data = page([
        (2, edgeTop + 40, 5, edgeTop + 120),
        (8, edgeTop - 5, 11, edgeTop + 16),
        (16, 0, 19, edgeTop - 2),
        (16, edgeTop + 1, 19, edgeTop + 4),
        (28, edgeTop - 10, 31, edgeTop - 4),
        (28, edgeTop + 1, 31, edgeTop + 90),
        (40, edgeBottom - 14, 43, edgeBottom + 12),
        (50, edgeTop + 90, 53, edgeBottom + 3),
      ]);
      keepLineInk(data, width, line: line, top: top);
      expect(alphaAt(data, 3, edgeTop + 60), 255, reason: 'letter');
      expect(alphaAt(data, 9, edgeTop - 4), 255, reason: 'rising mark');
      expect(alphaAt(data, 17, 10), 0, reason: 'letter above');
      expect(alphaAt(data, 17, edgeTop + 2), 0, reason: 'kasra above');
      expect(alphaAt(data, 29, edgeTop - 8), 255, reason: 'floating mark');
      expect(alphaAt(data, 41, edgeBottom - 10), 0, reason: 'mark below');
      expect(alphaAt(data, 51, edgeBottom + 2), 255, reason: 'descender');
    });

    test('clears every channel of a foreign pixel', () {
      final data = page([(10, 0, 13, edgeTop - 2)]);
      data.setUint8((5 * width + 11) * 4, 9);
      keepLineInk(data, width, line: line, top: top);
      expect(data.getUint32((5 * width + 11) * 4), 0);
    });
  });

  test('accentSource keeps the rosette bleed and drops the foreign sliver', () {
    final rosette = linesOf(91, 11).single;
    expect(
      accentSource(rosette, rowEdges(rosette, pageRectsOf(595))),
      const Rect.fromLTRB(786, 1355, 1302, 1517),
    );
    final last = linesOf(6, 31).last;
    expect(
      accentSource(last, rowEdges(last, pageRectsOf(131))),
      const Rect.fromLTRB(619, 1186, 1425, 1347),
    );
  });
}
