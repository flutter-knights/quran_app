import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/ayah_share/presentation/utils/share_card_layout.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_grid.dart';

import '../../../surah/mushaf_bounds_fixture.dart';
import '../../share_card_fixture.dart';

int _height(ShareCardLayout layout) => shareCardFrame(layout.textBottom).height;

Iterable<ShareCardSlice> _body(ShareCardLayout layout) =>
    layout.slices.skip(2).where((s) => s.layer != ShareCardLayer.basmala);

void main() {
  test('6:31 lays out three right-aligned rows at height 903', () {
    final layout = layoutFor(6, 31);
    expect(layout.rows, hasLength(3));
    expect(layout.scale, closeTo(0.7682, 1e-3));
    expect(_height(layout), closeTo(903, 1));
    for (final row in layout.rows) {
      expect(row.coreRight, closeTo(1008, 0.5));
    }
  });

  test('2:282 stacks fifteen rows at height 2461', () {
    final layout = layoutFor(2, 282);
    expect(layout.rows, hasLength(15));
    expect(_height(layout), closeTo(2461, 1));
  });

  test('16:127 carries its rosette tail on the previous row and refits', () {
    final layout = layoutFor(16, 127);
    final last = layout.rows.last;
    expect(layout.rows, hasLength(2));
    expect(layout.mergedTail, isTrue);
    expect(layout.scale, closeTo(0.737, 1e-3));
    expect(_height(layout), closeTo(757, 1));
    final accents = _body(
      layout,
    ).where((s) => s.layer == ShareCardLayer.accent);
    expect(accents, hasLength(1));
    final accent = accents.single;
    expect(accent.dst.top, greaterThanOrEqualTo(last.top));
    expect(accent.dst.bottom, lessThanOrEqualTo(last.top + layout.pitch + 1));
    expect(accent.dst.left, lessThan(last.coreLeft));
    expect(
      accent.dst.right,
      lessThan(last.coreLeft + 0.2 * (last.coreRight - last.coreLeft)),
    );
    expect(last.coreLeft, closeTo(72, 0.5));
    expect(last.coreRight, closeTo(1008, 0.5));
    final lastRowInk = _body(layout)
        .where(
          (s) => s.layer == ShareCardLayer.ink && s.dst.center.dy > last.top,
        )
        .toList();
    final leftmost = lastRowInk.reduce(
      (a, b) => a.dst.left <= b.dst.left ? a : b,
    );
    expect(leftmost.dst.left, closeTo(last.coreLeft, 0.5));
  });

  test('a one-row ayah is centred at the minimum height', () {
    final layout = layoutFor(108, 1);
    expect(layout.rows, hasLength(1));
    final row = layout.rows.single;
    expect((row.coreLeft + row.coreRight) / 2, closeTo(540, 0.5));
    expect(_height(layout), 670);
  });

  test('pages 1 and 2 centre every row', () {
    final layout = layoutFor(2, 2);
    expect(layout.rows, hasLength(2));
    for (final row in layout.rows) {
      expect((row.coreLeft + row.coreRight) / 2, closeTo(540, 0.5));
    }
    expect(_height(layoutFor(1, 1)), 670);
  });

  test('surahs 1 and 9 have no basmala', () {
    for (final (surah, ayah) in [(1, 1), (9, 1)]) {
      expect(
        layoutFor(surah, ayah).slices.map((s) => s.layer),
        isNot(contains(ShareCardLayer.basmala)),
      );
    }
    final layout = layoutFor(6, 31);
    final basmala = layout.slices.singleWhere(
      (s) => s.layer == ShareCardLayer.basmala,
    );
    expect(basmala.dst.left + basmala.dst.right, closeTo(1080, 1e-6));
    expect(basmala.dst.width, closeTo(0.37 * (1080 - 2 * 72), 1e-6));
    expect(basmala.page, 128);
    final rect = boundsOf(
      128,
    ).firstWhere((b) => b.ayah.surah == 6 && b.ayah.ayah == 0).lines.first;
    final band = gridBand(gridLineOf(rect));
    expect(basmala.line, gridLineOf(rect));
    expect(basmala.src.top, band.top - mushafInkMargin);
    expect(basmala.src.bottom, band.bottom + mushafInkMargin);
    final bs = basmala.dst.width / basmala.src.width;
    expect(basmala.dst.height, closeTo(basmala.src.height * bs, 1e-6));
  });

  test('ink rows cut their whole line window and keep the row pitch', () {
    final layout = layoutFor(6, 31);
    final rects = linesOf(6, 31);
    final ink = _body(
      layout,
    ).where((s) => s.layer == ShareCardLayer.ink).toList();
    expect(ink, hasLength(3));
    for (final (i, slice) in ink.indexed) {
      final edges = rowEdges(rects[i], pageRectsOf(131));
      final cell = rowSource(rects[i], edges);
      expect(slice.line, gridLineOf(rects[i]));
      expect(slice.src, lineInkSource(rects[i], edges));
      expect(
        slice.dst.top,
        closeTo(
          layout.rows[i].top + (slice.src.top - cell.top) * layout.scale,
          1e-6,
        ),
      );
      expect(slice.dst.height, closeTo(slice.src.height * layout.scale, 1e-6));
    }
    final others = layout.slices.where(
      (s) =>
          s.layer == ShareCardLayer.accent ||
          (s.layer == ShareCardLayer.ink && layout.slices.indexOf(s) < 2),
    );
    expect(others.map((s) => s.line).toSet(), {null});
  });

  test("only the ayah's last line has an accent slice", () {
    final layout = layoutFor(6, 31);
    final accents = _body(
      layout,
    ).where((s) => s.layer == ShareCardLayer.accent);
    expect(accents, hasLength(1));
    final rect = linesOf(6, 31).last;
    final edges = rowEdges(rect, pageRectsOf(131));
    expect(accents.single.page, 131);
    expect(accents.single.src, accentSource(rect, edges));
  });

  test('the header is centred and no larger than the text', () {
    final layout = layoutFor(6, 31);
    final header = layout.slices.take(2).toList();
    expect(header.map((s) => s.layer), [
      ShareCardLayer.ink,
      ShareCardLayer.accent,
    ]);
    for (final slice in header) {
      expect(slice.src, headerBoxFixture(0));
      expect(slice.dst.top, 72);
      expect(slice.dst.left + slice.dst.right, closeTo(1080, 1e-6));
    }
    expect(layout.headerScale, closeTo(0.6783, 1e-3));
    expect(layout.headerScale, lessThanOrEqualTo(layout.scale));
    expect(layoutFor(4, 1).slices.first.page, 76);
  });

  test('a narrow header box is capped at the text scale', () {
    final wide = layoutFor(6, 31);
    final slot = headerSlot(
      surah: 6,
      startPage: 128,
      startPageBounds: boundsOf(128),
    );
    final layout = shareCardLayout(
      ayah: const AyahIdentifier(surah: 6, ayah: 31),
      page: 131,
      pageBounds: boundsOf(131),
      startPage: 128,
      startPageBounds: boundsOf(128),
      header: (page: slot.page, box: const Rect.fromLTWH(0, 0, 600, 120)),
    );
    expect(layout.scale, wide.scale);
    expect(layout.headerScale, layout.scale);
    expect(layout.slices.first.dst.width, closeTo(600 * layout.scale, 1e-6));
  });

  test('a page 1–2 header over a full-width page spans the text column', () {
    final narrow = Rect.fromLTWH(305, headerBand(0).top + 4, 925, 150);
    ShareCardLayout layout(int ayah) => shareCardLayout(
      ayah: AyahIdentifier(surah: 2, ayah: ayah),
      page: quran.getPageNumber(2, ayah),
      pageBounds: boundsOf(quran.getPageNumber(2, ayah)),
      startPage: 2,
      startPageBounds: boundsOf(2),
      header: (page: 2, box: narrow),
    );
    final far = layout(255);
    expect(
      far.slices.first.dst.width,
      closeTo(mushafColumnWidth * far.scale, 1e-6),
    );
    final near = layout(2);
    expect(near.slices.first.dst.width, closeTo(925 * near.scale, 1e-6));
  });

  test('shareCardFrame centres short content', () {
    expect(shareCardFrame(400), (height: 670, dy: 95.0));
    expect(shareCardFrame(1000).dy, 0);
  });

  test('every ayah lays out', () {
    var maxRows = 0;
    for (var surah = 1; surah <= 114; surah++) {
      final startPage = quran.getPageNumber(surah, 1);
      final slot = headerSlot(
        surah: surah,
        startPage: startPage,
        startPageBounds: boundsOf(startPage),
      );
      for (var ayah = 1; ayah <= quran.getVerseCount(surah); ayah++) {
        final layout = layoutFor(surah, ayah);
        expect(layout.textBottom.isFinite, isTrue);
        expect(layout.scale.isFinite, isTrue);
        expect(layout.headerScale.isFinite, isTrue);
        expect(shareCardFrame(layout.textBottom).height, isPositive);
        if (layout.rows.length > maxRows) maxRows = layout.rows.length;
        final header = layout.slices.take(2).toList();
        expect(header.first.layer, ShareCardLayer.ink);
        expect(header.last.layer, ShareCardLayer.accent);
        expect(header.first.dst.width, greaterThan(0));
        expect(header.first.page, slot.page);
      }
    }
    expect(maxRows, 15);
  });
}
