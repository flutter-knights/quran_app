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

import '../../share_card_fixture.dart';

class _Pages {
  final paints = <String, ({Rect rect, int alpha})>{};
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
      });
    },
  );

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
      final renderer = ShareCardRenderer(loadImage: _Pages().load);
      final crops = await renderer.prepare(contentFor(6, 31));
      final image = await _decode(
        await renderer.compose(crops, colors: MushafPaper.cream.colors),
      );
      expect(image.width, 1080);
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

  testWidgets('the tafsir makes the card taller', (tester) async {
    await tester.runAsync(() async {
      final renderer = ShareCardRenderer(loadImage: _Pages().load);
      final crops = await renderer.prepare(contentFor(6, 31));
      final plain = await _decode(
        await renderer.compose(crops, colors: MushafPaper.cream.colors),
      );
      final withTafsir = await _decode(
        await renderer.compose(
          crops,
          colors: MushafPaper.cream.colors,
          tafsir: 'كلمة ' * 40,
        ),
      );
      expect(withTafsir.height, greaterThan(plain.height));
      plain.dispose();
      withTafsir.dispose();
      crops.dispose();
    });
  });

  testWidgets('a very long card is scaled to 4096 px high', (tester) async {
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
      image.dispose();
      crops.dispose();
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
