// Generates the two-layer mushaf assets for every page (1..604):
//   assets/mushaf/pages/page_NNN.png         -> BODY layer  (alpha mask)
//   assets/mushaf/pages/page_NNN_accent.png  -> ACCENT layer (alpha mask)
//   assets/mushaf/bounds/page_NNN.json       -> ayah highlight bounds
//
// Both PNGs are colourless alpha masks (RGB is black); the app tints them at
// runtime with two srcIn Image layers — body -> colorScheme.onSurface, accent
// -> colorScheme.secondary — so the pages adapt to light/dark themes.
//   - BODY  : verse text + surah NAME + basmala (at 0.8 size, 60% alpha)
//   - ACCENT: the ornamental header frame (paintSurahFrame) + the ayah-number rosettes
//
// Pipeline per page:
//   original TTF -> FontLoader -> ONE split-span list -> body & accent painters
//   (identical geometry) -> Picture -> PNG; getBoxesForSelection -> bounds JSON.
//
// The header decoration is drawn by paintSurahFrame
// (lib/features/surah/presentation/utils/surah_frame.dart) across the page's
// text column, 0.885 of a line tall; the surah name is centred in it.
// (Earlier versions stretched the QCF2BSML glyph 0xf2, and before that
// overlaid assets/images/header.png.)
//
// Rosette colouring: the ayah-end rosette is the last non-newline glyph of each
// verse; it is split into its own span so the accent layer can carry it while
// the body layer leaves a transparent gap. Splitting is geometry-neutral (QCF
// is glyph-per-PUA-codepoint), so bounds are byte-identical to the unsplit
// layout — verified against the committed bounds before the full run.
//
// All TextStyles set `height: lineHeight/fontSize`, so every painter line is
// exactly `lineHeight` tall and the header grid (`lineIndex * lineHeight`) is
// exact regardless of per-page QCF font metrics.
//
// FontSize factor 0.82 keeps the widest QCF lines within `_renderWidth`.
// Spillover guard trims a spurious trailing \n so wide pages stay within 15
// lines. Bounds: ayahs AND basmalas (basmala uses ayah:0). Horizontal edges
// snap within 60px; vertical tops/bottoms cluster at 6px.
//
//   flutter test test/tools/generate_mushaf_assets_test.dart --concurrency=1
//
// Post-step (optional, ~42% smaller): the emitted PNGs are alpha masks, so they
// quantize losslessly-enough with pngquant (the srcIn tint ignores RGB; only
// the alpha edge matters). Compress in place, e.g.:
//   find assets/mushaf/pages -name '*.png' -print0 \
//     | xargs -0 -n 40 pngquant --quality=60-90 --ext .png --force --skip-if-larger --

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/utils/surah_frame.dart';
import 'mushaf_page_builder.dart';

const double _renderWidth = 1536;
const double _aspect = 1.82;
const double _fontSizeFactor = 0.82;
// Fraction of page height reserved as blank bands for the Chrome overlay.
// Top band: Chrome header (surah name + juz). Bottom band: page-number ornament.
// The 15 text lines are compressed into the remaining (1 - top - bottom) area.
const double _topMarginFraction = 0.058;
const double _bottomMarginFraction = 0.033;
const String _outputPagesDir = 'assets/mushaf/pages';
const String _outputBoundsDir = 'assets/mushaf/bounds';
const String _headerFontFamily = 'QCF_P000';
const String _headerFontPath = 'assets/QCF2BSMLfonts/QCF2BSML.ttf';
const String _basmalaText = '!"#\n';
const String _headerPlaceholder = '​\n';
// Downward nudge so the surah name sits vertically centred in the frame.
const double _nameDyOffset = 12;
const double _frameHeightFraction = 0.885;
const double _basmalaScale = 0.8;
const double _basmalaAlpha = 0.6;

// Both layers are colourless alpha masks. `_opaque` = paint into the mask;
// `_clear` = reserve layout space but paint nothing.
const Color _opaque = Colors.black;
const Color _clear = Color(0x00000000);

const double _horizontalSnapTolerancePx = 60;
const double _verticalSnapTolerancePx = 6;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  if (Platform.environment['GENERATE_MUSHAF_ASSETS'] != 'true') {
    test(
      'generate mushaf assets',
      () {},
      skip: 'opt-in: run with GENERATE_MUSHAF_ASSETS=true',
    );
    return;
  }

  setUpAll(() async {
    await _loadFontFromTtf(_headerFontFamily, _headerFontPath);
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
      'assets/QCF2BSMLfonts/QCF2${pageNumber.toString().padLeft(3, '0')}.ttf';
  await _loadFontFromTtf(pageFontFamily, pageFontPath);

  final page = buildMushafPage(pageNumber);

  final pageHeight = _renderWidth * _aspect;
  final topMargin = pageHeight * _topMarginFraction;
  // Compress 15 lines into the content band between the two Chrome margins.
  final contentHeight =
      pageHeight * (1.0 - _topMarginFraction - _bottomMarginFraction);
  final lineHeight = contentHeight / 15;
  final fontSize = lineHeight * _fontSizeFactor / 1.8;

  TextStyle verse(Color c) => TextStyle(
    fontFamily: pageFontFamily,
    fontSize: fontSize,
    height: lineHeight / fontSize,
    color: c,
    locale: const Locale('ar'),
  );
  TextStyle basmala(Color c) => TextStyle(
    fontFamily: _headerFontFamily,
    fontSize: fontSize,
    height: lineHeight / fontSize,
    color: c,
    locale: const Locale('ar'),
  );

  final headerIndexes = page.surahHeadersIndexes.toSet();
  final basmalaIndexes = page.basmalaIndexes.toSet();

  // Spillover guard: trim the spurious trailing \n if the data source emitted
  // one more newline than fits the 15-line budget (14 newlines minus the one in
  // each header placeholder and each basmala).
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

  // ONE split-span descriptor list (role: body | basmala | rosette) feeds the
  // body painter, the accent painter, and the bounds — identical geometry.
  final descriptors = <({String text, String role})>[];
  // Highlight units = ayahs + basmalas. Basmalas use ayah=0.
  final units = <({int surah, int ayah, int start, int end})>[];
  final headerPlaceholders = <({int lineIndex, String name, int surah})>[];
  final basmalaLines = <int>[];
  var cursor = 0;
  var lineIndex = 0;
  var atLineStart = true;
  var surahCounter = 0;
  void add(String text, String role) {
    descriptors.add((text: text, role: role));
    cursor += text.length;
  }

  for (var i = 0; i <= ayahs.length; i++) {
    if (headerIndexes.contains(i)) {
      if (!atLineStart) lineIndex++;
      headerPlaceholders.add((
        lineIndex: lineIndex,
        name: page.surahNames[surahCounter],
        surah: i < page.ayahIdentifiers.length
            ? page.ayahIdentifiers[i].surah
            : page.ayahIdentifiers.last.surah + 1,
      ));
      add(_headerPlaceholder, 'body');
      lineIndex += '\n'.allMatches(_headerPlaceholder).length;
      atLineStart = _headerPlaceholder.endsWith('\n');
      surahCounter++;
    }
    if (basmalaIndexes.contains(i)) {
      final basmalaSurah = i < page.ayahIdentifiers.length
          ? page.ayahIdentifiers[i].surah
          : -1;
      final start = cursor;
      basmalaLines.add(lineIndex);
      add(_basmalaText, 'basmala');
      lineIndex += '\n'.allMatches(_basmalaText).length;
      atLineStart = _basmalaText.endsWith('\n');
      units.add((surah: basmalaSurah, ayah: 0, start: start, end: cursor));
    }
    if (i < ayahs.length) {
      final start = cursor;
      final ayahText = ayahs[i];
      // Split the trailing rosette (last non-newline rune) into its own span.
      final runes = ayahText.runes.toList();
      var last = runes.length - 1;
      while (last >= 0 && runes[last] == 0x0a) {
        last--;
      }
      if (last >= 0) {
        final body = String.fromCharCodes(runes.sublist(0, last));
        final rosette = String.fromCharCode(runes[last]);
        final tail = String.fromCharCodes(runes.sublist(last + 1));
        if (body.isNotEmpty) add(body, 'body');
        add(rosette, 'rosette');
        if (tail.isNotEmpty) add(tail, 'body');
      } else {
        add(ayahText, 'body');
      }
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

  TextStyle styleFor(String role, Color c) =>
      role == 'basmala' ? basmala(c) : verse(c);
  List<InlineSpan> spans(Map<String, Color> colors) => [
    for (final d in descriptors)
      TextSpan(text: d.text, style: styleFor(d.role, colors[d.role]!)),
  ];
  TextPainter layeredPainter(Map<String, Color> colors) => TextPainter(
    text: TextSpan(children: spans(colors)),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
    maxLines: 15,
  )..layout(minWidth: _renderWidth, maxWidth: _renderWidth);

  final bodyPainter = layeredPainter(const {
    'body': _opaque,
    'basmala': _clear,
    'rosette': _clear,
  });
  final accentPainter = layeredPainter(const {
    'body': _clear,
    'basmala': _clear,
    'rosette': _opaque,
  });

  expect(
    bodyPainter.didExceedMaxLines,
    isFalse,
    reason:
        'page $pageNumber exceeded 15-line budget '
        '(${bodyPainter.computeLineMetrics().length} lines, '
        '${page.surahHeadersIndexes.length} headers)',
  );

  var columnLeft = double.infinity;
  var columnRight = double.negativeInfinity;
  for (final u in units) {
    if (u.ayah == 0) continue;
    for (final b in bodyPainter.getBoxesForSelection(
      TextSelection(baseOffset: u.start, extentOffset: u.end),
    )) {
      if (b.left < columnLeft) columnLeft = b.left;
      if (b.right > columnRight) columnRight = b.right;
    }
  }
  final frameHalfWidth = math.max(
    _renderWidth / 2 - columnLeft,
    columnRight - _renderWidth / 2,
  );
  final frameHeight = lineHeight * _frameHeightFraction;
  Rect frameRect(int lineIndex) => Rect.fromLTWH(
    _renderWidth / 2 - frameHalfWidth,
    topMargin + lineIndex * lineHeight + (lineHeight - frameHeight) / 2,
    frameHalfWidth * 2,
    frameHeight,
  );
  final basmalaPainter = TextPainter(
    text: TextSpan(text: _basmalaText.trim(), style: basmala(_opaque)),
    textDirection: TextDirection.rtl,
    textAlign: TextAlign.center,
  )..layout(minWidth: _renderWidth, maxWidth: _renderWidth);

  // ---- BODY layer: painter + surah name + basmala ----
  final bodyImage = await _toImage(pageHeight, (canvas) {
    bodyPainter.paint(canvas, Offset(0, topMargin));
    for (final h in headerPlaceholders) {
      final headerY = topMargin + h.lineIndex * lineHeight;
      final namePainter = TextPainter(
        text: TextSpan(
          text: h.name,
          style: TextStyle(
            fontFamily: _headerFontFamily,
            fontSize: fontSize * 1.4,
            color: _opaque,
            locale: const Locale('ar'),
          ),
        ),
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
      )..layout(minWidth: _renderWidth, maxWidth: _renderWidth);
      namePainter.paint(
        canvas,
        Offset(
          0,
          headerY + (lineHeight - namePainter.height) / 2 + _nameDyOffset,
        ),
      );
    }
    for (final line in basmalaLines) {
      final top = topMargin + line * lineHeight;
      final center = Offset(_renderWidth / 2, top + lineHeight / 2);
      canvas.saveLayer(
        Rect.fromLTWH(0, top, _renderWidth, lineHeight),
        Paint()..color = _opaque.withValues(alpha: _basmalaAlpha),
      );
      canvas.translate(center.dx, center.dy);
      canvas.scale(_basmalaScale);
      canvas.translate(-center.dx, -center.dy);
      basmalaPainter.paint(canvas, Offset(0, top));
      canvas.restore();
    }
  });

  // ---- ACCENT layer: painter (rosettes) + frame glyph ----
  final accentImage = await _toImage(pageHeight, (canvas) {
    accentPainter.paint(canvas, Offset(0, topMargin));
    for (final h in headerPlaceholders) {
      paintSurahFrame(canvas, frameRect(h.lineIndex), _opaque);
    }
  });

  final pad = pageNumber.toString().padLeft(3, '0');
  final bodyFile = File('$_outputPagesDir/page_$pad.png');
  await bodyFile.writeAsBytes(await _png(bodyImage));
  final accentFile = File('$_outputPagesDir/page_${pad}_accent.png');
  await accentFile.writeAsBytes(await _png(accentImage));

  final bodyLen = bodyFile.lengthSync();
  expect(
    bodyLen,
    greaterThan(10 * 1024),
    reason: 'page $pageNumber body PNG too small ($bodyLen bytes)',
  );
  final accentLen = accentFile.lengthSync();
  expect(
    accentLen,
    greaterThan(0),
    reason: 'page $pageNumber accent PNG empty',
  );
  expect(
    accentLen,
    lessThan(bodyLen),
    reason: 'page $pageNumber accent PNG unexpectedly large ($accentLen)',
  );

  // --- Bounds: gather, snap, normalize, write JSON (from body geometry) ---
  final unitBoxes = <List<ui.TextBox>>[];
  for (final u in units) {
    final boxes = bodyPainter.getBoxesForSelection(
      TextSelection(baseOffset: u.start, extentOffset: u.end),
      boxHeightStyle: ui.BoxHeightStyle.includeLineSpacingMiddle,
    );
    expect(
      boxes,
      isNotEmpty,
      reason:
          'page $pageNumber unit surah=${u.surah} ayah=${u.ayah} has no rects',
    );
    if (u.ayah == 0) {
      final corrected = boxes
          .map(
            (b) => ui.TextBox.fromLTRBD(
              _renderWidth / 2 - (_renderWidth / 2 - b.left) * _basmalaScale,
              b.top,
              _renderWidth / 2 + (_renderWidth / 2 - b.left) * _basmalaScale,
              b.bottom,
              b.direction,
            ),
          )
          .toList();
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
          .map(
            (r) => {
              'x': double.parse((r.left / _renderWidth).toStringAsFixed(5)),
              'y': double.parse(
                ((r.top + topMargin) / pageHeight).toStringAsFixed(5),
              ),
              'w': double.parse((r.width / _renderWidth).toStringAsFixed(5)),
              'h': double.parse((r.height / pageHeight).toStringAsFixed(5)),
            },
          )
          .toList(),
    });
  }
  expect(bounds, isNotEmpty, reason: 'page $pageNumber has no units');

  final jsonFile = File('$_outputBoundsDir/page_$pad.json');
  double norm(double v, double of) => double.parse((v / of).toStringAsFixed(5));
  await jsonFile.writeAsString(
    jsonEncode({
      'page': pageNumber,
      'ayahs': bounds,
      if (headerPlaceholders.isNotEmpty)
        'headers': [
          for (final h in headerPlaceholders)
            if (frameRect(h.lineIndex) case final r)
              {
                'surah': h.surah,
                'x': norm(r.left, _renderWidth),
                'y': norm(r.top, pageHeight),
                'w': norm(r.width, _renderWidth),
                'h': norm(r.height, pageHeight),
              },
        ],
    }),
  );
}

Future<ui.Image> _toImage(double pageHeight, void Function(Canvas) draw) async {
  final rec = ui.PictureRecorder();
  draw(Canvas(rec));
  return rec.endRecording().toImage(_renderWidth.toInt(), pageHeight.toInt());
}

Future<List<int>> _png(ui.Image img) async {
  final bytes = await img.toByteData(format: ui.ImageByteFormat.png);
  return bytes!.buffer.asUint8List();
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
  return clusters.map((c) => c.reduce((a, b) => a + b) / c.length).toList();
}

double _snap(double value, List<double> clusters, double tolerance) {
  for (final c in clusters) {
    if ((value - c).abs() <= tolerance) return c;
  }
  return value;
}

// Loads from the on-disk path rather than rootBundle: the QCF fonts are not
// registered in pubspec.yaml at runtime (728e772 stripped the 605 QCF font
// entries), so the asset bundle can't find them. The generator only runs at
// build time, where direct disk access is fine.
//
// Reads the original TTF straight into the FontLoader. (Earlier this pipeline
// loaded WOFF and converted WOFF -> SFNT in-Dart, because flutter_test didn't
// shape PUA codepoints from WOFF reliably; the original TTFs in
// assets/QCF2BSMLfonts shape identically and skip that step.)
Future<void> _loadFontFromTtf(String family, String diskPath) async {
  final ttfBytes = await File(diskPath).readAsBytes();
  final loader = FontLoader(family);
  loader.addFont(Future.value(ByteData.sublistView(ttfBytes)));
  await loader.load();
}
