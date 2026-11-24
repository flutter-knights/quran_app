import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/features/ayah_share/domain/entities/reel_segment.dart';
import 'package:quran_app/features/ayah_share/presentation/utils/reel_frame_painter.dart';
import 'package:quran_app/features/ayah_share/presentation/utils/share_card_renderer.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

import '../../share_card_fixture.dart';

const deviceFooter = 3 * 18.75 + 2 * reelFooterPad;

double _lineHeight() {
  final painter = TextPainter(
    text: TextSpan(text: 'ا', style: reelTafsirStyle),
    textDirection: TextDirection.rtl,
  )..layout();
  final line = painter.preferredLineHeight;
  painter.dispose();
  return line;
}

double _height(String text) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: reelTafsirStyle),
    textDirection: TextDirection.rtl,
  )..layout(maxWidth: shareCardTextWidth);
  final height = painter.height;
  painter.dispose();
  return height;
}

final _longBody = List.generate(60, (i) => 'هذه جملة رقم $i.').join(' ');

void main() {
  test('a short card keeps its size and leaves room for tafsir', () {
    final geometry = reelFrameGeometry(
      layoutFor(6, 31),
      footerHeight: deviceFooter,
      headingHeight: 25,
    );
    expect(geometry.scale, 1);
    expect(geometry.tafsirMaxHeight, greaterThan(3 * 21.6));
  });

  test('2:282 shrinks into the space above the footer', () {
    final layout = layoutFor(2, 282);
    final geometry = reelFrameGeometry(
      layout,
      footerHeight: deviceFooter,
      headingHeight: 25,
    );
    expect(
      geometry.scale,
      closeTo((1920 - deviceFooter) / (layout.textBottom + 72), 1e-9),
    );
    expect(geometry.scale, lessThan(1));
    expect(geometry.tafsirMaxHeight, 0);
  });

  test('only 2:282 and 4:12 are scaled', () {
    final scaled = <String>{};
    for (var surah = 1; surah <= 114; surah++) {
      for (var ayah = 1; ayah <= quran.getVerseCount(surah); ayah++) {
        final geometry = reelFrameGeometry(
          layoutFor(surah, ayah),
          footerHeight: deviceFooter,
          headingHeight: 25,
        );
        if (geometry.scale < 1) scaled.add('$surah:$ayah');
      }
    }
    expect(scaled, {'2:282', '4:12'});
  });

  test('a tafsir that fits stays whole', () {
    expect(fitReelTafsir('جملة قصيرة.', maxHeight: 400), 'جملة قصيرة.');
  });

  test('a long tafsir is cut after the last full sentence that fits', () {
    final maxHeight = 5 * _lineHeight();
    final cut = fitReelTafsir(_longBody, maxHeight: maxHeight)!;
    expect(cut, endsWith('. …'));
    final prefix = cut.substring(0, cut.length - 2);
    expect(_longBody, startsWith(prefix));
    expect(_height(cut), lessThanOrEqualTo(maxHeight));
    final next = _longBody.indexOf('.', prefix.length) + 1;
    expect(
      _height('${_longBody.substring(0, next)} …'),
      greaterThan(maxHeight),
    );
  });

  test('fewer than three lines of room drops the tafsir', () {
    expect(fitReelTafsir(_longBody, maxHeight: 2.5 * _lineHeight()), isNull);
  });

  test('with no sentence end in reach it cuts at a word', () {
    final body = '${List.generate(300, (i) => 'كلمة$i').join(' ')}.';
    final maxHeight = 4 * _lineHeight();
    final cut = fitReelTafsir(body, maxHeight: maxHeight)!;
    expect(cut, endsWith(' …'));
    expect(cut, isNot(contains('.')));
    final prefix = cut.substring(0, cut.length - 2);
    expect(body, startsWith(prefix));
    expect(_height(cut), lessThanOrEqualTo(maxHeight));
    final next = body.indexOf(' ', prefix.length + 1);
    expect(_height('${body.substring(0, next)} …'), greaterThan(maxHeight));
  });

  testWidgets('a frame is a 1080×1920 PNG on the paper', (tester) async {
    await tester.runAsync(() async {
      final colors = MushafPaper.night.colors;
      final png = await ReelFramePainter().paint(
        ShareCardCrops(
          layout: layoutFor(6, 31),
          pieces: const [],
          basmalaOpacity: 0.42,
        ),
        colors: colors,
        footer: 'x',
        tafsir: 'جملة.',
      );
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      expect(image.width, 1080);
      expect(image.height, 1920);
      final raw = (await image.toByteData())!;
      final at = (2 * image.width + 2) * 4;
      expect(
        ui.Color.fromARGB(
          raw.getUint8(at + 3),
          raw.getUint8(at),
          raw.getUint8(at + 1),
          raw.getUint8(at + 2),
        ),
        colors.background,
      );
      image.dispose();
    });
  });

  testWidgets('the footer sits in the bottom band and nothing above it', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final colors = MushafPaper.night.colors;
      final png = await ReelFramePainter().paint(
        ShareCardCrops(
          layout: layoutFor(6, 31),
          pieces: const [],
          basmalaOpacity: 0.42,
        ),
        colors: colors,
        footer: 'ـــــ',
      );
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      final raw = (await image.toByteData())!;
      bool inked(int y) {
        for (var x = 0; x < image.width; x++) {
          final at = (y * image.width + x) * 4;
          final pixel = ui.Color.fromARGB(
            raw.getUint8(at + 3),
            raw.getUint8(at),
            raw.getUint8(at + 1),
            raw.getUint8(at + 2),
          );
          if (pixel != colors.background) return true;
        }
        return false;
      }

      const footerHeight = 3 * 18.75;
      final top = (reelHeight - reelFooterPad - footerHeight).floor();
      final bottom = (reelHeight - reelFooterPad).ceil();
      expect([for (var y = top; y < bottom; y++) inked(y)], contains(true));
      expect([for (var y = 0; y < top - 2; y++) inked(y)], everyElement(false));
      expect([
        for (var y = bottom + 1; y < 1920; y++) inked(y),
      ], everyElement(false));
      image.dispose();
    });
  });

  testWidgets('a tall card with a long tafsir still exports 1080×1920', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final png = await ReelFramePainter().paint(
        ShareCardCrops(
          layout: layoutFor(2, 282),
          pieces: const [],
          basmalaOpacity: 0.42,
        ),
        colors: MushafPaper.cream.colors,
        footer: 'x',
        tafsir: _longBody,
      );
      final codec = await ui.instantiateImageCodec(png);
      final image = (await codec.getNextFrame()).image;
      codec.dispose();
      expect(image.width, 1080);
      expect(image.height, 1920);
      image.dispose();
    });
  });
}
