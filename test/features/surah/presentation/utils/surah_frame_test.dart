import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/utils/surah_frame.dart';

Future<({Rect ink, ui.Image image, List<int> alpha})> _render(
  Rect frame,
  Size canvas,
) async {
  final recorder = ui.PictureRecorder();
  paintSurahFrame(Canvas(recorder), frame, Colors.black);
  final image = await recorder.endRecording().toImage(
    canvas.width.toInt(),
    canvas.height.toInt(),
  );
  final bytes = (await image.toByteData(
    format: ui.ImageByteFormat.rawRgba,
  ))!.buffer.asUint8List();
  final w = image.width;
  final h = image.height;
  final alpha = [for (var i = 3; i < bytes.length; i += 4) bytes[i]];
  var minX = w, minY = h, maxX = -1, maxY = -1;
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      if (alpha[y * w + x] != 0) {
        if (x < minX) minX = x;
        if (x > maxX) maxX = x;
        if (y < minY) minY = y;
        if (y > maxY) maxY = y;
      }
    }
  }
  return (
    ink: Rect.fromLTRB(
      minX.toDouble(),
      minY.toDouble(),
      maxX + 1.0,
      maxY + 1.0,
    ),
    image: image,
    alpha: alpha,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('surahFrameIsNarrow', () {
    test('a text-column frame on a regular page keeps both medallions', () {
      expect(surahFrameIsNarrow(const Size(1215, 150)), isFalse);
    });

    test('the 0.60 column of pages 1 and 2 drops to one medallion a side', () {
      expect(surahFrameIsNarrow(const Size(922, 150)), isTrue);
    });

    test('the threshold scales with the frame height', () {
      expect(surahFrameIsNarrow(const Size(1215 / 2, 75)), isFalse);
      expect(surahFrameIsNarrow(const Size(922 / 2, 75)), isTrue);
    });
  });

  group('paintSurahFrame', () {
    for (final width in [922.0, 1215.0, 1310.0]) {
      test(
        'ink fills the frame rect and stays inside it at width $width',
        () async {
          final frame = Rect.fromLTWH(20, 10, width, 150);
          final r = await _render(frame, Size(width + 40, 170));
          expect(r.ink.left, closeTo(frame.left, 2));
          expect(r.ink.right, closeTo(frame.right, 2));
          expect(r.ink.top, closeTo(frame.top, 2));
          expect(r.ink.bottom, closeTo(frame.bottom, 2));
        },
      );
    }

    test('is mirror-symmetric about its vertical centre', () async {
      const frame = Rect.fromLTWH(0, 0, 1216, 150);
      final r = await _render(frame, const Size(1216, 150));
      final w = r.image.width;
      var mismatched = 0;
      var inked = 0;
      for (var y = 0; y < r.image.height; y++) {
        for (var x = 0; x < w ~/ 2; x++) {
          final a = r.alpha[y * w + x] > 127;
          final b = r.alpha[y * w + (w - 1 - x)] > 127;
          if (a || b) inked++;
          if (a != b) mismatched++;
        }
      }
      expect(mismatched / inked, lessThan(0.02));
    });

    test('leaves the cartouche centre clear for the surah name', () async {
      const frame = Rect.fromLTWH(0, 0, 1215, 150);
      final r = await _render(frame, const Size(1215, 150));
      final w = r.image.width;
      for (var y = 30; y < 120; y++) {
        for (var x = 1215 ~/ 2 - 150; x < 1215 ~/ 2 + 150; x++) {
          expect(r.alpha[y * w + x], 0, reason: 'ink at ($x, $y)');
        }
      }
    });
  });
}
