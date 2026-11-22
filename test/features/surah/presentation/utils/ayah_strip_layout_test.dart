import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';
import 'package:quran_app/features/surah/presentation/utils/ayah_strip_layout.dart';

void main() {
  const image = Size(1536, 2795);
  const a = NormalizedRect(x: .1, y: .2, w: .8, h: .05);
  const b = NormalizedRect(x: .5, y: .25, w: .4, h: .05);
  final aHeight = .05 * 2795 * 320 / (.8 * 1536);

  test('a full line spans the strip width', () {
    final layout = ayahStripLayout(lines: [a], image: image, width: 320);
    expect(layout.slices.single.dst, Rect.fromLTWH(0, 0, 320, aHeight));
    expect(
      layout.slices.single.src,
      Rect.fromLTWH(.1 * 1536, .2 * 2795, .8 * 1536, .05 * 2795),
    );
  });

  test('a shorter line keeps the common scale and sits at the right edge', () {
    final layout = ayahStripLayout(lines: [a, b], image: image, width: 320);
    expect(layout.slices[1].dst.left, closeTo(160, 1e-9));
    expect(layout.slices[1].dst.width, closeTo(160, 1e-9));
  });

  test('a short line keeps the full-line scale at the right edge', () {
    const short = NormalizedRect(x: .5, y: .2, w: .09, h: .05);
    final layout = ayahStripLayout(lines: [short], image: image, width: 320);
    final dst = layout.slices.single.dst;
    expect(dst.width, closeTo(.09 * 320 / ayahStripFullLine, 1e-9));
    expect(dst.right, closeTo(320, 1e-9));
    expect(layout.height, closeTo(aHeight, 1e-9));
  });

  test('a line wider than a full line still spans the strip', () {
    const wide = NormalizedRect(x: .05, y: .2, w: .85, h: .05);
    final layout = ayahStripLayout(lines: [wide], image: image, width: 320);
    expect(layout.slices.single.dst.width, closeTo(320, 1e-9));
  });

  test('a zero-width line, or a width that is not finite, draws nothing', () {
    const empty = NormalizedRect(x: .5, y: .2, w: 0, h: .05);
    expect(
      ayahStripLayout(lines: [empty], image: image, width: 320).slices,
      isEmpty,
    );
    for (final width in [0.0, -1.0, double.infinity]) {
      final layout = ayahStripLayout(lines: [a], image: image, width: width);
      expect(layout.slices, isEmpty);
      expect(layout.height, 0);
    }
  });

  test('lines stack top to bottom', () {
    final layout = ayahStripLayout(lines: [a, b], image: image, width: 320);
    expect(layout.slices[1].dst.top, layout.slices[0].dst.bottom);
    expect(layout.height, closeTo(layout.slices[1].dst.bottom, 1e-9));
  });

  test('at most three lines are drawn', () {
    final layout = ayahStripLayout(
      lines: [a, a, a, a, a],
      image: image,
      width: 320,
    );
    expect(layout.slices, hasLength(ayahStripMaxLines));
  });

  test('no lines is an empty strip', () {
    final layout = ayahStripLayout(lines: [], image: image, width: 320);
    expect(layout.slices, isEmpty);
    expect(layout.height, 0);
  });

  test('the strip height depends only on the page aspect', () {
    final full = ayahStripLayout(lines: [a, b], image: image, width: 320);
    final half = ayahStripLayout(
      lines: [a, b],
      image: const Size(768, 1397.5),
      width: 320,
    );
    expect(half.height, closeTo(full.height, 1e-9));
    for (var i = 0; i < 2; i++) {
      expect(half.slices[i].dst.top, closeTo(full.slices[i].dst.top, 1e-9));
      expect(half.slices[i].dst.width, closeTo(full.slices[i].dst.width, 1e-9));
    }
  });

  test(
    'the cache width follows the strip width and never passes the page width',
    () {
      expect(ayahStripCacheWidth(320, 3), 1200);
      expect(ayahStripCacheWidth(600, 3), 1536);
    },
  );
}
