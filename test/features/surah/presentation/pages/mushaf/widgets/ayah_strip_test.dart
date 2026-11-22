import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
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

class _RecordingCanvas implements Canvas {
  final rects = <(Rect, Color)>[];
  final images = <(ui.Image, Rect, Rect, Paint)>[];

  @override
  void drawRect(Rect rect, Paint paint) => rects.add((rect, paint.color));

  @override
  void drawImageRect(ui.Image image, Rect src, Rect dst, Paint paint) =>
      images.add((image, src, dst, paint));

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FailingImage extends ImageProvider<_FailingImage> {
  @override
  Future<_FailingImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);

  @override
  ImageStreamCompleter loadImage(
    _FailingImage key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(Future.error(StateError('no page')));
}

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
    expect(requested.first, 1200);
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
    expect(requested, [800, 1200]);
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

  testWidgets('the painter crops the scaled source and tints it with ink', (
    tester,
  ) async {
    final image = (await tester.runAsync(
      () => createTestImage(width: 64, height: 116),
    ))!;
    const src = Rect.fromLTWH(150, 560, 1200, 140);
    const dst = Rect.fromLTWH(0, 10, 320, 36);
    final canvas = _RecordingCanvas();
    AyahStripPainter(
      image: image,
      slices: const [(src: src, dst: dst)],
      colors: colors,
    ).paint(canvas, const Size(320, 60));
    const k = 64 / 1536;
    final (paper, paperColor) = canvas.rects.single;
    expect(paper, const Rect.fromLTWH(0, 0, 320, 60));
    expect(paperColor.toARGB32(), colors.background.toARGB32());
    final (drawn, source, destination, paint) = canvas.images.single;
    expect(drawn, same(image));
    expect(source.left, closeTo(src.left * k, 1e-9));
    expect(source.top, closeTo(src.top * k, 1e-9));
    expect(source.right, closeTo(src.right * k, 1e-9));
    expect(source.bottom, closeTo(src.bottom * k, 1e-9));
    expect(destination, dst);
    expect(paint.colorFilter, ColorFilter.mode(colors.ink, BlendMode.srcIn));
  });

  testWidgets('without an image the painter draws only the paper', (
    tester,
  ) async {
    final canvas = _RecordingCanvas();
    AyahStripPainter(
      image: null,
      slices: const [
        (src: Rect.fromLTWH(0, 0, 10, 10), dst: Rect.fromLTWH(0, 0, 10, 10)),
      ],
      colors: colors,
    ).paint(canvas, const Size(320, 60));
    expect(canvas.rects, hasLength(1));
    expect(canvas.images, isEmpty);
  });

  testWidgets('a failed decode is reported and the strip collapses', (
    tester,
  ) async {
    await tester.pumpWidget(
      _host(
        AyahStrip(
          page: 5,
          lines: _lines,
          colors: colors,
          imageFor: (_) => _FailingImage(),
        ),
      ),
    );
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());
    expect(tester.getSize(find.byType(AyahStrip)).height, 0);
    expect(find.byKey(const ValueKey('ayah-strip-paint')), findsNothing);
  });

  testWidgets('a page change after a failure tries the new page again', (
    tester,
  ) async {
    final bytes = await _png(tester);
    Widget strip(int page) => _host(
      AyahStrip(
        page: page,
        lines: _lines,
        colors: colors,
        imageFor: (_) => page == 5 ? _FailingImage() : MemoryImage(bytes),
      ),
    );
    await tester.pumpWidget(strip(5));
    await tester.pump();
    await tester.pump();
    expect(tester.takeException(), isA<StateError>());
    await tester.pumpWidget(strip(6));
    await tester.runAsync(
      () => Future.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    expect(find.byKey(const ValueKey('ayah-strip-paint')), findsOneWidget);
  });

  testWidgets('an unbounded or zero width draws nothing and throws nothing', (
    tester,
  ) async {
    final bytes = await _png(tester);
    final strip = AyahStrip(
      page: 5,
      lines: _lines,
      colors: colors,
      imageFor: (_) => MemoryImage(bytes),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: strip,
          ),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('ayah-strip-paint')), findsNothing);
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Align(child: SizedBox(width: 0, child: strip)),
        ),
      ),
    );
    expect(tester.takeException(), isNull);
    expect(find.byKey(const ValueKey('ayah-strip-paint')), findsNothing);
  });
}
