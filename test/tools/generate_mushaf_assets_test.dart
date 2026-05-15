// Generates assets/mushaf/pages/page_NNN.png and assets/mushaf/bounds/page_NNN.json
// for every mushaf page (1..604). Run with --concurrency=1 to avoid FontLoader races.
//
// Pipeline per page:
//   WOFF -> in-Dart SFNT (TTF) -> FontLoader -> TextPainter -> Picture -> PNG
//   getBoxesForSelection -> normalized ayah rects -> JSON
//
// Multi-surah pages: every entry in `surahHeadersIndexes` reserves a line in
// the painter via a `​\n` placeholder; the decorative header.png frame +
// centered surah name are overlaid at each placeholder's Y position after the
// painter has been drawn. This keeps mid-page surah headers (e.g. page 604,
// where Falaq and Nas start mid-page) visually identical to the top header.
//
// Validation per page: PNG > 10KB AND ayahs non-empty AND every ayah has rects.
//
//   flutter test test/tools/generate_mushaf_assets_test.dart --concurrency=1

import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_local_data_source.dart';

import 'woff_to_ttf.dart';

const String _headerImagePath = 'assets/images/header.png';
const double _renderWidth = 1536;
const double _aspect = 1.82;
const String _outputPagesDir = 'assets/mushaf/pages';
const String _outputBoundsDir = 'assets/mushaf/bounds';
const String _headerFontFamily = 'QCF_P000';
const String _headerFontPath = 'assets/fonts/QCF/QCF2BSML.woff';
const String _basmalaText = '!"#\n';
const String _headerPlaceholder = '​\n';

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

  final page = const MushafLocalDataSource().getPage(pageNumber);

  final fontSize = _renderWidth / 15 * 0.9;
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

  final children = <InlineSpan>[];
  final ayahRanges = <({int start, int end})>[];
  final headerPlaceholders = <({int offset, String name})>[];
  var cursor = 0;
  var surahCounter = 0;
  for (var i = 0; i <= page.ayahs.length; i++) {
    if (headerIndexes.contains(i)) {
      headerPlaceholders.add((
        offset: cursor,
        name: page.surahNames[surahCounter],
      ));
      children.add(TextSpan(text: _headerPlaceholder, style: verseStyle));
      cursor += _headerPlaceholder.length;
      surahCounter++;
    }
    if (basmalaIndexes.contains(i)) {
      children.add(TextSpan(text: _basmalaText, style: basmalaStyle));
      cursor += _basmalaText.length;
    }
    if (i < page.ayahs.length) {
      final start = cursor;
      final ayahText = page.ayahs[i];
      children.add(TextSpan(text: ayahText, style: verseStyle));
      cursor += ayahText.length;
      ayahRanges.add((start: start, end: cursor));
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
    final boxes = painter.getBoxesForSelection(
      TextSelection(
        baseOffset: h.offset,
        extentOffset: h.offset + _headerPlaceholder.length,
      ),
      boxHeightStyle: ui.BoxHeightStyle.includeLineSpacingMiddle,
    );
    final headerY = boxes.isEmpty
        ? painter
            .getOffsetForCaret(TextPosition(offset: h.offset), Rect.zero)
            .dy
        : boxes.first.top;

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

  final bounds = <Map<String, dynamic>>[];
  for (var i = 0; i < ayahRanges.length; i++) {
    final range = ayahRanges[i];
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
      boxHeightStyle: ui.BoxHeightStyle.includeLineSpacingMiddle,
    );
    expect(boxes, isNotEmpty,
        reason: 'page $pageNumber ayah index $i produced no rects');
    final ident = page.ayahIdentifiers[i];
    bounds.add({
      'surah': ident.surah,
      'ayah': ident.ayah,
      'lines': boxes
          .map((b) => {
                'x': double.parse((b.left / _renderWidth).toStringAsFixed(5)),
                'y': double.parse((b.top / pageHeight).toStringAsFixed(5)),
                'w': double.parse(((b.right - b.left) / _renderWidth)
                    .toStringAsFixed(5)),
                'h': double.parse(((b.bottom - b.top) / pageHeight)
                    .toStringAsFixed(5)),
              })
          .toList(),
    });
  }
  expect(bounds, isNotEmpty, reason: 'page $pageNumber has no ayahs');

  final jsonFile = File(
      '$_outputBoundsDir/page_${pageNumber.toString().padLeft(3, '0')}.json');
  await jsonFile.writeAsString(jsonEncode({
    'page': pageNumber,
    'ayahs': bounds,
  }));
}

Future<void> _loadFontFromWoff(String family, String assetPath) async {
  final woffBytes = (await rootBundle.load(assetPath)).buffer.asUint8List();
  final ttfBytes = woffToSfnt(woffBytes);
  final loader = FontLoader(family);
  loader.addFont(Future.value(ByteData.view(ttfBytes.buffer)));
  await loader.load();
}

Future<ui.Image> _loadImage(String assetPath) async {
  final data = await rootBundle.load(assetPath);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  return frame.image;
}
