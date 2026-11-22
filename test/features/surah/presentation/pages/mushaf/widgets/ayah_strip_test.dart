import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_strip.dart';
import 'package:quran_app/features/surah/presentation/utils/ayah_strip_layout.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/surah/presentation/utils/reader_rules.dart';

const _lines = [
  NormalizedRect(x: .1, y: .2, w: .8, h: .05),
  NormalizedRect(x: .5, y: .25, w: .4, h: .05),
];

Future<Uint8List> _png(WidgetTester t) async => (await t.runAsync(() async {
  final img = await createTestImage(width: 64, height: 116);
  return (await img.toByteData(
    format: ui.ImageByteFormat.png,
  ))!.buffer.asUint8List();
}))!;

Widget _host(Widget child) => MaterialApp(
  home: Scaffold(
    body: Align(
      alignment: Alignment.topCenter,
      child: SizedBox(width: 320, child: child),
    ),
  ),
);

void main() {
  final colors = MushafPaper.cream.colors;

  testWidgets('sizes itself from the line rects before the image decodes', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final bytes = await _png(tester);
    await tester.pumpWidget(
      _host(
        AyahStrip(
          page: 5,
          lines: _lines,
          colors: colors,
          imageFor: (_) => MemoryImage(bytes),
        ),
      ),
    );
    final expected = ayahStripLayout(
      lines: _lines,
      image: mushafPageSize,
      width: 320,
    ).height;
    expect(tester.getSize(find.byType(AyahStrip)).height, expected);
  });

  testWidgets('asks for the page decoded at strip width', (tester) async {
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final bytes = await _png(tester);
    final requested = <int>[];
    await tester.pumpWidget(
      _host(
        AyahStrip(
          page: 5,
          lines: _lines,
          colors: colors,
          imageFor: (w) {
            requested.add(w);
            return MemoryImage(bytes);
          },
        ),
      ),
    );
    expect(requested.first, 960);
  });

  testWidgets('an ayah with no lines draws nothing', (tester) async {
    final bytes = await _png(tester);
    await tester.pumpWidget(
      _host(
        AyahStrip(
          page: 5,
          lines: const [],
          colors: colors,
          imageFor: (_) => MemoryImage(bytes),
        ),
      ),
    );
    expect(tester.getSize(find.byType(AyahStrip)).height, 0);
    expect(find.byKey(const ValueKey('ayah-strip-paint')), findsNothing);
  });

  testWidgets('paints once the image decodes', (tester) async {
    final bytes = await _png(tester);
    await tester.pumpWidget(
      _host(
        AyahStrip(
          page: 5,
          lines: _lines,
          colors: colors,
          imageFor: (_) => MemoryImage(bytes),
        ),
      ),
    );
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    final paint = tester.widget<CustomPaint>(
      find.byKey(const ValueKey('ayah-strip-paint')),
    );
    expect((paint.painter! as AyahStripPainter).image, isNotNull);
  });

  testWidgets('a page change drops the old image and requests the new page', (
    tester,
  ) async {
    final bytes = await _png(tester);
    final requested = <int>[];
    Widget strip(int page) => _host(
      AyahStrip(
        page: page,
        lines: _lines,
        colors: colors,
        imageFor: (w) {
          requested.add(page);
          return MemoryImage(bytes);
        },
      ),
    );
    ui.Image? imageOf() =>
        (tester
                    .widget<CustomPaint>(
                      find.byKey(const ValueKey('ayah-strip-paint')),
                    )
                    .painter!
                as AyahStripPainter)
            .image;

    await tester.pumpWidget(strip(5));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(imageOf(), isNotNull);
    expect(requested, [5]);

    await tester.pumpWidget(strip(6));
    expect(imageOf(), isNull);
    expect(requested, [5, 6]);
  });

  testWidgets('a pixel ratio change decodes again at the new width', (
    tester,
  ) async {
    addTearDown(tester.view.reset);
    final bytes = await _png(tester);
    final requested = <int>[];
    final host = _host(
      AyahStrip(
        page: 5,
        lines: _lines,
        colors: colors,
        imageFor: (w) {
          requested.add(w);
          return MemoryImage(bytes);
        },
      ),
    );
    tester.view.devicePixelRatio = 2;
    await tester.pumpWidget(host);
    tester.view.devicePixelRatio = 3;
    await tester.pumpWidget(host);
    await tester.pump();
    expect(requested, [640, 960]);
  });

  testWidgets('removing the strip before the image decodes throws nothing', (
    tester,
  ) async {
    final bytes = await _png(tester);
    await tester.pumpWidget(
      _host(
        AyahStrip(
          page: 5,
          lines: _lines,
          colors: colors,
          imageFor: (_) => MemoryImage(bytes),
        ),
      ),
    );
    await tester.pumpWidget(_host(const SizedBox.shrink()));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
