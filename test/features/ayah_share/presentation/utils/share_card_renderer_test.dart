import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/assets_dir.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/ayah_share/presentation/utils/share_card_layout.dart';
import 'package:quran_app/features/ayah_share/presentation/utils/share_card_renderer.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_grid.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/surah/presentation/utils/reader_rules.dart';

import '../../../surah/mushaf_bounds_fixture.dart';
import '../../share_card_fixture.dart';

class _Pages {
  final paints = <String, ({Rect rect, int alpha})>{};
  final blocks = <String, List<Rect>>{};
  final asked = <String>[];
  final images = <ui.Image>[];

  Future<ui.Image> load(String asset) async {
    asked.add(asset);
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final paint = paints[asset];
    if (paint != null) {
      canvas.drawRect(
        paint.rect,
        Paint()..color = Color.fromARGB(paint.alpha, 255, 255, 255),
      );
    }
    for (final block in blocks[asset] ?? const <Rect>[]) {
      canvas.drawRect(block, Paint()..color = const Color(0xFF000000));
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(1536, 2795);
    picture.dispose();
    images.add(image);
    return image;
  }
}

Rect _headerRect(int surah) {
  final content = contentFor(surah, 1);
  final slot = headerSlot(
    surah: surah,
    startPage: content.startPage,
    startPageBounds: content.startPageBounds,
  );
  final band = headerBand(slot.line);
  return Rect.fromLTRB(200, band.top + 20, 1300, band.bottom - 20);
}

_Pages _headerPages() =>
    _Pages()
      ..paints[AssetsDir.mushafPage(128)] = (rect: _headerRect(6), alpha: 255);

_Pages _fixturePages() {
  final content = contentFor(6, 1);
  final slot = headerSlot(
    surah: 6,
    startPage: content.startPage,
    startPageBounds: content.startPageBounds,
  );
  return _Pages()
    ..paints[AssetsDir.mushafPage(128)] = (
      rect: headerBoxFixture(slot.line),
      alpha: 255,
    );
}

Future<ui.Image> _decode(Uint8List bytes) async {
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
}

void main() {
  test('alphaBounds finds the inked box', () {
    final data = ByteData(8 * 4 * 4);
    data.setUint8((1 * 8 + 2) * 4 + 3, 9);
    data.setUint8((2 * 8 + 5) * 4 + 3, 9);
    expect(alphaBounds([data], 8, 4), const Rect.fromLTRB(2, 1, 6, 3));
    final faint = ByteData(8 * 4 * 4)..setUint8(3, 8);
    expect(alphaBounds([faint], 8, 4), isNull);
  });

  test('alphaBounds takes the max over layers', () {
    final ink = ByteData(8 * 4 * 4);
    final accent = ByteData(8 * 4 * 4)..setUint8((3 * 8 + 6) * 4 + 3, 200);
    expect(alphaBounds([ink, accent], 8, 4), const Rect.fromLTRB(6, 3, 7, 4));
  });

  test('tafsirBodyStyle steps down past 600 characters', () {
    expect(tafsirBodyStyle('ا' * 600).fontSize, 14);
    expect(tafsirBodyStyle('ا' * 601).fontSize, 12);
    expect(tafsirBodyStyle('ا').height, 1.8);
    expect(tafsirBodyStyle('ا' * 601).height, 1.8);
  });

  testWidgets(
    'prepare touches only the header, basmala and ayah pages and disposes them',
    (tester) async {
      await tester.runAsync(() async {
        final pages = _Pages();
        final crops = await ShareCardRenderer(
          loadImage: pages.load,
        ).prepare(contentFor(6, 31));
        expect(pages.asked.toSet(), {
          AssetsDir.mushafPage(128),
          AssetsDir.mushafPageAccent(128),
          AssetsDir.mushafPage(131),
          AssetsDir.mushafPageAccent(131),
        });
        expect(pages.images, isNotEmpty);
        expect(pages.images.every((i) => i.debugDisposed), isTrue);
        crops.dispose();

        final previous = _Pages();
        final header = await ShareCardRenderer(
          loadImage: previous.load,
        ).prepare(contentFor(4, 1));
        expect(previous.asked.toSet(), {
          AssetsDir.mushafPage(76),
          AssetsDir.mushafPageAccent(76),
          AssetsDir.mushafPage(77),
          AssetsDir.mushafPageAccent(77),
        });
        header.dispose();
      });
    },
  );

  testWidgets('prepare decodes each page once', (tester) async {
    await tester.runAsync(() async {
      final split = _Pages();
      final crops = await ShareCardRenderer(
        loadImage: split.load,
      ).prepare(contentFor(6, 31));
      expect(split.asked, hasLength(4));
      expect(split.asked.toSet(), hasLength(4));
      crops.dispose();

      final single = _Pages();
      final one = await ShareCardRenderer(
        loadImage: single.load,
      ).prepare(contentFor(6, 1));
      expect(single.asked, hasLength(2));
      one.dispose();
    });
  });

  testWidgets('prepare disposes every page when a load fails', (tester) async {
    await tester.runAsync(() async {
      final pages = _Pages();
      final failing = AssetsDir.mushafPageAccent(131);
      final renderer = ShareCardRenderer(
        loadImage: (asset) => asset == failing
            ? Future.error(StateError('boom'))
            : pages.load(asset),
      );
      await expectLater(
        renderer.prepare(contentFor(6, 31)),
        throwsA(isA<StateError>()),
      );
      expect(pages.images, isNotEmpty);
      expect(pages.images.every((i) => i.debugDisposed), isTrue);
    });
  });

  Future<int Function(int x, int y)> alphaOf(
    ({ShareCardSlice slice, ui.Image image}) piece,
  ) async {
    final data = (await piece.image.toByteData())!;
    final src = piece.slice.src;
    return (x, y) => data.getUint8(
      (((y - src.top).round()) * piece.image.width + (x - src.left).round()) *
              4 +
          3,
    );
  }

  testWidgets('prepare keeps only the row line ink in each ink row', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final rect = linesOf(6, 31).first;
      final line = gridLineOf(rect);
      final band = gridBand(line);
      final pages = _Pages()
        ..blocks[AssetsDir.mushafPage(131)] = [
          Rect.fromLTRB(400, band.top - 50.0, 420, band.top - 30.0),
          Rect.fromLTRB(500, band.top - 15.0, 520, band.top + 40.0),
        ];
      final crops = await ShareCardRenderer(
        loadImage: pages.load,
      ).prepare(contentFor(6, 31));
      final row = crops.pieces.firstWhere(
        (p) => p.slice.page == 131 && p.slice.line == line,
      );
      final alpha = await alphaOf(row);
      expect(alpha(410, band.top - 40), 0);
      expect(alpha(510, band.top - 10), 255);
      expect(alpha(510, band.top + 30), 255);
      crops.dispose();
    });
  });

  testWidgets('the basmala opacity ignores the next line ink', (tester) async {
    await tester.runAsync(() async {
      for (final surah in [6, 8, 66]) {
        final crops = await ShareCardRenderer().prepare(contentFor(surah, 1));
        expect(
          crops.basmalaOpacity,
          closeTo(0.42 * 255 / 153, 0.01),
          reason: 'surah $surah',
        );
        crops.dispose();
      }
    });
  });

  testWidgets('3:123 keeps the pause mark above its first row', (tester) async {
    await tester.runAsync(() async {
      final crops = await ShareCardRenderer().prepare(contentFor(3, 123));
      final rect = linesOf(3, 123).first;
      final cell = rowSource(rect, rowEdges(rect, pageRectsOf(66)));
      final band = gridBand(gridLineOf(rect));
      final row = crops.pieces.firstWhere(
        (p) => p.slice.page == 66 && p.slice.layer == ShareCardLayer.ink,
      );
      final alpha = await alphaOf(row);
      var above = 0;
      var foreign = 0;
      for (var x = cell.left.round(); x < cell.right; x++) {
        for (var y = band.top - mushafInkMargin; y < cell.top; y++) {
          if (alpha(x, y) == 0) continue;
          if (y < band.top - 25) foreign++;
          above++;
        }
      }
      expect(above, greaterThan(100));
      expect(foreign, 0);
      crops.dispose();
    });
  });

  testWidgets('loadAssetImage decodes a bundled page', (tester) async {
    await tester.runAsync(() async {
      final image = await loadAssetImage(AssetsDir.mushafPage(1));
      expect(image.width, 1536);
      expect(image.height, 2795);
      image.dispose();
    });
  });

  testWidgets('prepare trims the header to its inked box', (tester) async {
    await tester.runAsync(() async {
      final crops = await ShareCardRenderer(
        loadImage: _headerPages().load,
      ).prepare(contentFor(6, 31));
      final header = crops.layout.slices.take(2);
      expect(header.map((s) => s.src), everyElement(_headerRect(6)));
      crops.dispose();
    });
  });

  testWidgets('prepare normalises the basmala opacity', (tester) async {
    await tester.runAsync(() async {
      final content = contentFor(6, 31);
      final rect = content.startPageBounds
          .firstWhere((b) => b.ayah.surah == 6 && b.ayah.ayah == 0)
          .lines
          .first;
      final src = rowSource(rect, (
        left: rect.x * mushafPageSize.width,
        right: (rect.x + rect.w) * mushafPageSize.width,
        leftOpen: false,
        rightOpen: false,
      ));
      final pages = _Pages()
        ..paints[AssetsDir.mushafPage(128)] = (rect: src, alpha: 128);
      final basmala = await ShareCardRenderer(
        loadImage: pages.load,
      ).prepare(content);
      expect(basmala.basmalaOpacity, closeTo(0.42 * 255 / 128, 0.01));
      basmala.dispose();

      final none = await ShareCardRenderer(
        loadImage: _Pages().load,
      ).prepare(contentFor(9, 1));
      expect(none.basmalaOpacity, 0.42);
      none.dispose();
    });
  });

  testWidgets('compose exports a 1080-wide PNG at the layout height', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final renderer = ShareCardRenderer(loadImage: _fixturePages().load);
      final crops = await renderer.prepare(contentFor(6, 31));
      final image = await _decode(
        await renderer.compose(crops, colors: MushafPaper.cream.colors),
      );
      expect(image.width, 1080);
      expect(image.height, 903);
      expect(image.height, shareCardFrame(crops.layout.textBottom).height);
      image.dispose();
      crops.dispose();
    });
  });

  testWidgets('a recompose never loads a page again', (tester) async {
    await tester.runAsync(() async {
      final pages = _Pages();
      final renderer = ShareCardRenderer(loadImage: pages.load);
      final crops = await renderer.prepare(contentFor(6, 31));
      final loads = pages.asked.length;
      await renderer.compose(crops, colors: MushafPaper.cream.colors);
      await renderer.compose(crops, colors: MushafPaper.sepia.colors);
      expect(pages.asked.length, loads);
      crops.dispose();
    });
  });

  testWidgets('a night paper card is dark with light ink', (tester) async {
    await tester.runAsync(() async {
      final renderer = ShareCardRenderer(loadImage: _headerPages().load);
      final crops = await renderer.prepare(contentFor(6, 31));
      final image = await _decode(
        await renderer.compose(crops, colors: MushafPaper.night.colors),
      );
      final raw = (await image.toByteData())!;
      List<int> pixel(int x, int y) {
        final i = (y * image.width + x) * 4;
        return [for (var c = 0; c < 4; c++) raw.getUint8(i + c)];
      }

      expect(pixel(0, 0), [0x14, 0x12, 0x10, 0xFF]);
      final center = crops.layout.slices.first.dst.center;
      final dy = shareCardFrame(crops.layout.textBottom).dy;
      final ink = pixel(center.dx.round(), (center.dy + dy).round());
      for (final (i, want) in [0xEC, 0xE3, 0xCF, 0xFF].indexed) {
        expect(ink[i], closeTo(want, 2));
      }
      image.dispose();
      crops.dispose();
    });
  });

  testWidgets('the tafsir block draws its rule, diamond and text', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final renderer = ShareCardRenderer(loadImage: _Pages().load);
      final crops = await renderer.prepare(contentFor(6, 31));
      final colors = MushafPaper.cream.colors;
      final plain = await _decode(
        await renderer.compose(crops, colors: colors),
      );
      final withTafsir = await _decode(
        await renderer.compose(crops, colors: colors, tafsir: 'كلمة ' * 40),
      );
      expect(withTafsir.height, greaterThan(plain.height));
      final plainRaw = (await plain.toByteData())!;
      final tafsirRaw = (await withTafsir.toByteData())!;

      List<int> pixel(ByteData raw, ui.Image image, int x, int y) {
        final i = (y * image.width + x) * 4;
        return [for (var c = 0; c < 4; c++) raw.getUint8(i + c)];
      }

      List<int> over(Color fore, int alpha) {
        final back = colors.background.toARGB32();
        final top = fore.toARGB32();
        return [
          for (final shift in [16, 8, 0])
            (((back >> shift) & 0xFF) * (255 - alpha) +
                    ((top >> shift) & 0xFF) * alpha) ~/
                255,
          0xFF,
        ];
      }

      bool near(List<int> got, List<int> want) => [
        for (final (i, c) in want.indexed) (got[i] - c).abs() <= 2,
      ].every((ok) => ok);

      final tafsirTop =
          crops.layout.textBottom + shareCardTafsirGap * crops.layout.pitch;
      final rows = [tafsirTop.floor() - 1, tafsirTop.floor()];
      final background = over(colors.background, 0);
      final rule = over(colors.accent, 150);
      final diamond = over(colors.accent, 200);

      for (final (x, want) in [(300, rule), (540, diamond)]) {
        expect(
          rows.any((y) => near(pixel(tafsirRaw, withTafsir, x, y), want)),
          isTrue,
          reason: 'x=$x expected $want',
        );
        for (final y in rows) {
          expect(y, lessThan(plain.height));
          expect(pixel(plainRaw, plain, x, y), background);
        }
      }

      final accent = over(colors.accent, 255);
      final ink2 = over(colors.ink2, 255);
      var heading = false;
      var body = false;
      for (var y = rows.last + 36; y < withTafsir.height; y++) {
        for (var x = 0; x < withTafsir.width; x++) {
          final got = pixel(tafsirRaw, withTafsir, x, y);
          heading = heading || near(got, accent);
          body = body || near(got, ink2);
        }
      }
      expect(heading, isTrue);
      expect(body, isTrue);
      withTafsir.dispose();
      plain.dispose();
      crops.dispose();
    });
  });

  testWidgets('a very long card is scaled to 4096 px high and stays opaque', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final renderer = ShareCardRenderer(loadImage: _Pages().load);
      final crops = await renderer.prepare(contentFor(2, 282));
      final image = await _decode(
        await renderer.compose(
          crops,
          colors: MushafPaper.cream.colors,
          tafsir: 'كلمة ' * 3000,
        ),
      );
      expect(image.height, 4096);
      expect(image.width, lessThan(1080));
      final raw = (await image.toByteData())!;
      for (var y = 0; y < image.height; y++) {
        final edge = (y * image.width + image.width - 1) * 4 + 3;
        expect(raw.getUint8(edge), 0xFF);
      }
      image.dispose();
      crops.dispose();
    });
  });

  testWidgets('dispose is idempotent', (tester) async {
    await tester.runAsync(() async {
      final crops = await ShareCardRenderer(
        loadImage: _Pages().load,
      ).prepare(contentFor(6, 31));
      crops.dispose();
      expect(crops.dispose, returnsNormally);
    });
  });

  testWidgets('dispose releases every crop', (tester) async {
    await tester.runAsync(() async {
      final crops = await ShareCardRenderer(
        loadImage: _Pages().load,
      ).prepare(contentFor(6, 31));
      crops.dispose();
      expect(crops.pieces, isNotEmpty);
      expect(crops.pieces.every((p) => p.image.debugDisposed), isTrue);
    });
  });
}
