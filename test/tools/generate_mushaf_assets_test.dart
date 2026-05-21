// Generates assets/mushaf/pages/page_NNN.png and assets/mushaf/bounds/page_NNN.json
// for every mushaf page (1..604). Run with --concurrency=1 to avoid FontLoader races.
//
// Pipeline per page:
//   WOFF -> in-Dart SFNT (TTF) -> FontLoader -> TextPainter -> Picture -> PNG
//   getBoxesForSelection -> normalized bounds (snapped) -> JSON
//
// Multi-surah pages: every entry in `surahHeadersIndexes` reserves a line in
// the painter via a `​\n` placeholder; the decorative header.png frame +
// centered surah name are overlaid at each placeholder's `lineIndex *
// lineHeight` after the painter has been drawn. Keeps mid-page surah headers
// (e.g. page 604, where Falaq and Nas start mid-page) visually identical to
// the top header.
//
// Header positioning uses `lineIndex * lineHeight` rather than
// `getBoxesForSelection(...).first.top`, because the latter's value drifts by
// 5-30 px across pages: includeLineSpacingMiddle distributes half-leading
// proportionally to the line's font ascent/descent, and each page uses a
// different per-page QCF font with different metrics. Every TextStyle here
// sets `height: lineHeight/fontSize`, so the line grid is exact.
//
// Spillover guard (Fix 2): on a few pages (303, 307, 335, 443, …) the
// `quran.line_break.dart` symbols-per-line config undercounts total symbols
// by 1, so `_injectLineBreaks` emits one extra `\n` that pushes a 1-2 glyph
// tail onto a 16th painter line. We pre-trim the last \n from the last ayah
// that has one so the tail merges back onto line 15.
//
// FontSize factor 0.82 (was 0.85, was 0.9) keeps the widest QCF lines within
// `_renderWidth` so they don't word-wrap, and reduces the margin variance on
// pages 303 and 335 (inherently wide glyphs). At 0.85 those lines had ~11 px
// margin; at 0.82 they have ~37 px. Trade-off: ~9 % smaller glyphs vs 0.9,
// more margin left/right — visible but acceptable.
//
// Bounds units: ayahs AND basmalas are recorded. Basmala bounds use
// `ayah: 0`, matching the convention used by per-surah basmala audio files.
//
// Bounds snapping: only the page-wide leftmost and rightmost edges snap
// (within 60 px tolerance at 1536 px width). Vertical tops/bottoms cluster
// at 6 px to remove 1-2 px hairline gaps between adjacent rows. Mid-line
// ayah-to-ayah transitions stay at their actual midpoint positions.
//
// Validation per page: PNG > 10 KB AND every unit (ayah or basmala) has
// rects AND painter doesn't exceed 15 lines.
//
//   flutter test test/tools/generate_mushaf_assets_test.dart --concurrency=1

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'mushaf_page_builder.dart';
import 'woff_to_ttf.dart';

const String _headerImagePath = 'assets/images/header.png';
const double _renderWidth = 1536;
const double _aspect = 1.82;
const double _fontSizeFactor = 0.82;
const String _outputPagesDir = 'assets/mushaf/pages';
const String _outputBoundsDir = 'assets/mushaf/bounds';
const String _headerFontFamily = 'QCF_P000';
const String _headerFontPath = 'assets/fonts/QCF/QCF2BSML.woff';
const String _basmalaText = '!"#\n';
const String _headerPlaceholder = '​\n';

const double _horizontalSnapTolerancePx = 60;
const double _verticalSnapTolerancePx = 6;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await _loadFontFromWoff(_headerFontFamily, _headerFontPath);
    Directory(_outputPagesDir).createSync(recursive: true);
    Directory(_outputBoundsDir).createSync(recursive: true);
  });

  for (var pageNumber = 1; pageNumber <= 604; pageNumber++) {
    test('generate page $pageNumber', () async {
      await _renderPage(pageNumber);
    });
  }
}

Future<void> _renderPage(int pageNumber) async {
  final pageFontFamily = 'QCF_P${pageNumber.toString().padLeft(3, '0')}';
  final pageFontPath =
      'assets/fonts/QCF/QCF2${pageNumber.toString().padLeft(3, '0')}.woff';
  await _loadFontFromWoff(pageFontFamily, pageFontPath);

  final page = buildMushafPage(pageNumber);

  final fontSize = _renderWidth / 15 * _fontSizeFactor;
  final lineHeight = _renderWidth / 15 * 1.8;
  final pageHeight = _renderWidth * _aspect;

  final verseStyle = TextStyle(
    fontFamily: pageFontFamily,
    fontSize: fontSize,
    height: lineHeight / fontSize,
    color: Colors.black,
    locale: const Locale('ar'),
  );
  final headerNameStyle = TextStyle(
    fontFamily: _headerFontFamily,
    fontSize: fontSize * 1.4,
    color: Colors.black,
    locale: const Locale('ar'),
  );
  final basmalaStyle = TextStyle(
    fontFamily: _headerFontFamily,
    fontSize: fontSize,
    height: lineHeight / fontSize,
    color: Colors.black,
    locale: const Locale('ar'),
  );

  final headerIndexes = page.surahHeadersIndexes.toSet();
  final basmalaIndexes = page.basmalaIndexes.toSet();

  // Fix 2: trim the spurious trailing \n if the data source emitted one
  // more newline than fits in the 15-line budget. Budget = 14 newlines
  // for 15 painter lines, minus one already-contained-in-each header
  // placeholder and one in each basmala.
  final ayahs = List<String>.from(page.ayahs);
  final ayahNlBudget = 14 - headerIndexes.length - basmalaIndexes.length;
  var ayahNlCount = 0;
  for (final a in ayahs) {
    ayahNlCount += '\n'.allMatches(a).length;
  }
  if (ayahNlCount > ayahNlBudget) {
    for (var i = ayahs.length - 1; i >= 0; i--) {
      final idx = ayahs[i].lastIndexOf('\n');
      if (idx < 0) continue;
      ayahs[i] = ayahs[i].replaceRange(idx, idx + 1, '');
      break;
    }
  }

  final children = <InlineSpan>[];
  // Highlight units = ayahs + basmalas. Basmalas use ayah=0.
  final units = <({int surah, int ayah, int start, int end})>[];
  // lineIndex is captured BEFORE the placeholder's own '\n' is appended, so it
  // maps to the painter line the header occupies — independent of per-page
  // QCF font metrics. See header positioning below.
  final headerPlaceholders = <({int lineIndex, String name})>[];
  var cursor = 0;
  var lineIndex = 0;
  // True when the painter cursor sits at the start of a fresh line (i.e., the
  // last appended text ended with `\n`, OR nothing has been appended yet).
  // The spillover guard above can strip the trailing `\n` from the last ayah
  // even when that `\n` is the *only* separator between the last ayah and a
  // trailing surah header (e.g. pages 445, 452 — Yaseen → Saaffat, Saaffat →
  // Sad). Without this guard we'd draw the header image on the same line as
  // the last ayah's tail. We bump `lineIndex` for the header so its image
  // lands on the next visual line; the placeholder's own `\n` still creates
  // that empty line in the painter, so the maxLines budget is respected.
  var atLineStart = true;
  var surahCounter = 0;
  for (var i = 0; i <= ayahs.length; i++) {
    if (headerIndexes.contains(i)) {
      if (!atLineStart) lineIndex++;
      headerPlaceholders.add((
        lineIndex: lineIndex,
        name: page.surahNames[surahCounter],
      ));
      children.add(TextSpan(text: _headerPlaceholder, style: verseStyle));
      cursor += _headerPlaceholder.length;
      lineIndex += '\n'.allMatches(_headerPlaceholder).length;
      atLineStart = _headerPlaceholder.endsWith('\n');
      surahCounter++;
    }
    if (basmalaIndexes.contains(i)) {
      final basmalaSurah = i < page.ayahIdentifiers.length
          ? page.ayahIdentifiers[i].surah
          : -1;
      final start = cursor;
      children.add(TextSpan(text: _basmalaText, style: basmalaStyle));
      cursor += _basmalaText.length;
      lineIndex += '\n'.allMatches(_basmalaText).length;
      atLineStart = _basmalaText.endsWith('\n');
      units.add((surah: basmalaSurah, ayah: 0, start: start, end: cursor));
    }
    if (i < ayahs.length) {
      final start = cursor;
      final ayahText = ayahs[i];
      children.add(TextSpan(text: ayahText, style: verseStyle));
      cursor += ayahText.length;
      lineIndex += '\n'.allMatches(ayahText).length;
      atLineStart = ayahText.endsWith('\n');
      final ident = page.ayahIdentifiers[i];
      units.add((
        surah: ident.surah,
        ayah: ident.ayah,
        start: start,
        end: cursor,
      ));
    }
  }

  final painter = TextPainter(
    text: TextSpan(children: children),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
    maxLines: 15,
  );
  painter.layout(minWidth: _renderWidth, maxWidth: _renderWidth);

  expect(painter.didExceedMaxLines, isFalse,
      reason: 'page $pageNumber exceeded 15-line budget '
          '(${painter.computeLineMetrics().length} lines, '
          '${page.surahHeadersIndexes.length} headers)');

  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder);

  painter.paint(canvas, Offset.zero);

  final headerImage = await _loadImage(_headerImagePath);
  final headerTint = Paint()
    ..colorFilter =
        const ColorFilter.mode(Colors.black, BlendMode.srcIn);
  for (final h in headerPlaceholders) {
    // Deterministic: every style sets `height: lineHeight/fontSize`, so every
    // painter line is exactly `lineHeight` tall regardless of which QCF font
    // the line uses. `boxes.first.top` from includeLineSpacingMiddle drifted
    // by 5-30 px across pages because the half-leading above line 0 is
    // distributed proportionally to the line's font ascent/descent — and
    // those differ per QCF page font.
    final headerY = h.lineIndex * lineHeight;

    canvas.drawImageRect(
      headerImage,
      Rect.fromLTWH(
          0, 0, headerImage.width.toDouble(), headerImage.height.toDouble()),
      Rect.fromLTWH(0, headerY, _renderWidth, lineHeight),
      headerTint,
    );

    final namePainter = TextPainter(
      text: TextSpan(text: h.name, style: headerNameStyle),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    );
    namePainter.layout(minWidth: _renderWidth, maxWidth: _renderWidth);
    final nameDy = headerY + (lineHeight - namePainter.height) / 2;
    namePainter.paint(canvas, Offset(0, nameDy + 4));
  }

  final picture = recorder.endRecording();
  final image =
      await picture.toImage(_renderWidth.toInt(), pageHeight.toInt());
  final pngBytes = await image.toByteData(format: ui.ImageByteFormat.png);
  final pngFile = File(
      '$_outputPagesDir/page_${pageNumber.toString().padLeft(3, '0')}.png');
  await pngFile.writeAsBytes(pngBytes!.buffer.asUint8List());

  final pngLen = pngFile.lengthSync();
  expect(pngLen, greaterThan(10 * 1024),
      reason: 'page $pageNumber PNG too small ($pngLen bytes)');

  // --- Bounds: gather, snap, normalize, write JSON ---------------------
  final unitBoxes = <List<ui.TextBox>>[];
  for (final u in units) {
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: u.start, extentOffset: u.end),
      boxHeightStyle: ui.BoxHeightStyle.includeLineSpacingMiddle,
    );
    expect(boxes, isNotEmpty,
        reason:
            'page $pageNumber unit surah=${u.surah} ayah=${u.ayah} has no rects');
    if (u.ayah == 0) {
      final corrected = boxes.map((b) => ui.TextBox.fromLTRBD(
            b.left, b.top, _renderWidth - b.left, b.bottom, b.direction,
          )).toList();
      unitBoxes.add(corrected);
    } else {
      unitBoxes.add(boxes);
    }
  }

  final snappedBoxes = _snapBoundsAcrossPage(unitBoxes);

  final bounds = <Map<String, dynamic>>[];
  for (var i = 0; i < snappedBoxes.length; i++) {
    final rects = snappedBoxes[i];
    final u = units[i];
    bounds.add({
      'surah': u.surah,
      'ayah': u.ayah,
      'lines': rects
          .map((r) => {
                'x': double.parse((r.left / _renderWidth).toStringAsFixed(5)),
                'y': double.parse((r.top / pageHeight).toStringAsFixed(5)),
                'w':
                    double.parse((r.width / _renderWidth).toStringAsFixed(5)),
                'h':
                    double.parse((r.height / pageHeight).toStringAsFixed(5)),
              })
          .toList(),
    });
  }
  expect(bounds, isNotEmpty, reason: 'page $pageNumber has no units');

  final jsonFile = File(
      '$_outputBoundsDir/page_${pageNumber.toString().padLeft(3, '0')}.json');
  await jsonFile.writeAsString(jsonEncode({
    'page': pageNumber,
    'ayahs': bounds,
  }));
}

List<List<Rect>> _snapBoundsAcrossPage(List<List<ui.TextBox>> boxesPerUnit) {
  var pageLeft = double.infinity;
  var pageRight = double.negativeInfinity;
  final allTops = <double>[];
  final allBottoms = <double>[];
  for (final boxes in boxesPerUnit) {
    for (final b in boxes) {
      if (b.left < pageLeft) pageLeft = b.left;
      if (b.right > pageRight) pageRight = b.right;
      allTops.add(b.top);
      allBottoms.add(b.bottom);
    }
  }

  final topClusters = _cluster1D(allTops, _verticalSnapTolerancePx);
  final bottomClusters = _cluster1D(allBottoms, _verticalSnapTolerancePx);

  return boxesPerUnit
      .map(
        (boxes) => boxes.map((b) {
          final newLeft = (b.left - pageLeft) <= _horizontalSnapTolerancePx
              ? pageLeft
              : b.left;
          final newRight = (pageRight - b.right) <= _horizontalSnapTolerancePx
              ? pageRight
              : b.right;
          return Rect.fromLTRB(
            newLeft,
            _snap(b.top, topClusters, _verticalSnapTolerancePx),
            newRight,
            _snap(b.bottom, bottomClusters, _verticalSnapTolerancePx),
          );
        }).toList(),
      )
      .toList();
}

List<double> _cluster1D(List<double> values, double tolerance) {
  if (values.isEmpty) return const [];
  final sorted = [...values]..sort();
  final clusters = <List<double>>[
    [sorted.first],
  ];
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i] - clusters.last.last <= tolerance) {
      clusters.last.add(sorted[i]);
    } else {
      clusters.add([sorted[i]]);
    }
  }
  return clusters
      .map((c) => c.reduce((a, b) => a + b) / c.length)
      .toList();
}

double _snap(double value, List<double> clusters, double tolerance) {
  for (final c in clusters) {
    if ((value - c).abs() <= tolerance) return c;
  }
  return value;
}

// Loads from the on-disk path rather than rootBundle: the WOFF fonts and
// header.png are not registered in pubspec.yaml at runtime (728e772 stripped
// the 605 QCF font entries), so the asset bundle can't find them. The
// generator only runs at build time, where direct disk access is fine.
Future<void> _loadFontFromWoff(String family, String diskPath) async {
  final woffBytes = await File(diskPath).readAsBytes();
  final ttfBytes = woffToSfnt(woffBytes);
  final loader = FontLoader(family);
  loader.addFont(Future.value(ByteData.view(ttfBytes.buffer)));
  await loader.load();
}

Future<ui.Image> _loadImage(String diskPath) async {
  final bytes = await File(diskPath).readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}
