import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'dart:ui' show Rect;

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/assets_dir.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_grid.dart';
import 'package:quran_app/features/surah/presentation/utils/reader_rules.dart';

import '../../mushaf_bounds_fixture.dart';

const _width = 1536;

typedef _LineInk = ({int top, Uint32List pixels});

Future<Uint32List> _page(int page) async {
  final codec = await ui.instantiateImageCodec(
    File(AssetsDir.mushafPage(page)).readAsBytesSync(),
  );
  final image = (await codec.getNextFrame()).image;
  codec.dispose();
  final rgba = (await image.toByteData())!;
  image.dispose();
  return rgba.buffer.asUint32List();
}

_LineInk _lineInk(Uint32List page, int line) {
  final band = gridBand(line);
  final top = band.top - mushafInkMargin;
  final pixels = page.sublist(
    top * _width,
    (band.bottom + mushafInkMargin) * _width,
  );
  keepLineInk(pixels.buffer.asByteData(), _width, line: line, top: top);
  return (top: top, pixels: pixels);
}

List<_LineInk> _lines(Uint32List page) => [
  for (var line = 0; line < 15; line++) _lineInk(page, line),
];

bool _kept(_LineInk ink, int x, int y) =>
    ink.pixels[(y - ink.top) * _width + x] >>> 24 != 0;

void main() {
  testWidgets('every ink pixel near a line edge goes to exactly one line', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final failures = <String>[];
      for (var page = 1; page <= 604 && failures.length < 20; page++) {
        final pixels = await _page(page);
        final lines = _lines(pixels);
        for (final (line, ink) in lines.indexed) {
          final last = ink.pixels.length - _width;
          for (var x = 0; x < _width; x++) {
            if (ink.pixels[x] != 0 || ink.pixels[last + x] != 0) {
              failures.add('page $page line $line reaches its window edge');
              break;
            }
          }
        }
        for (var line = 1; line < 15; line++) {
          final edge = gridBand(line).top;
          for (
            var y = edge - mushafInkMargin;
            y < edge + mushafInkMargin;
            y++
          ) {
            for (var x = 0; x < _width; x++) {
              if (pixels[y * _width + x] >>> 24 == 0) continue;
              final above = _kept(lines[line - 1], x, y);
              final below = _kept(lines[line], x, y);
              if (above == below) {
                failures.add('page $page ($x, $y): above $above, below $below');
              }
            }
          }
        }
      }
      expect(failures, isEmpty);
    });
  }, timeout: const Timeout(Duration(minutes: 5)));

  testWidgets('a cut row keeps its own marks and drops the next line', (
    tester,
  ) async {
    await tester.runAsync(() async {
      int inkIn(_LineInk ink, Rect area) {
        var count = 0;
        for (var y = area.top.round(); y < area.bottom; y++) {
          for (var x = area.left.round(); x < area.right; x++) {
            if (ink.pixels[(y - ink.top) * _width + x] >>> 24 > 60) count++;
          }
        }
        return count;
      }

      final first = linesOf(3, 123).first;
      final firstCell = rowSource(first, rowEdges(first, pageRectsOf(66)));
      final page66 = _lines(await _page(66));
      expect(
        inkIn(
          page66[gridLineOf(first)],
          Rect.fromLTRB(
            firstCell.left,
            firstCell.top - 25,
            firstCell.right,
            firstCell.top + 1,
          ),
        ),
        greaterThan(30),
        reason: 'the pause mark over أذلة straddles the old crop top',
      );

      final last = linesOf(2, 136).last;
      final lastCell = rowSource(last, rowEdges(last, pageRectsOf(21)));
      final next = linesOf(2, 137).first;
      expect(gridLineOf(next), gridLineOf(last) + 1);
      final page21 = _lines(await _page(21));
      final seam = Rect.fromLTRB(
        lastCell.left,
        lastCell.bottom - 2,
        lastCell.right,
        lastCell.bottom,
      );
      expect(inkIn(page21[gridLineOf(last)], seam), 0);
      expect(inkIn(page21[gridLineOf(next)], seam), greaterThan(30));
      expect(mushafPageSize.width, _width);
    });
  });
}
