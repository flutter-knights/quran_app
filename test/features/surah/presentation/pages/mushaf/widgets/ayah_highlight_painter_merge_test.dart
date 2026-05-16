import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/ayah_bound_entity.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_highlight_painter.dart';

class _RecordingCanvas extends Mock implements Canvas {}

void main() {
  setUpAll(() {
    registerFallbackValue(Path());
    registerFallbackValue(Paint());
    registerFallbackValue(RRect.zero);
  });

  const ayah = AyahIdentifier(surah: 2, ayah: 255);
  const size = Size(100, 100);

  AyahBoundEntity boundWith(List<NormalizedRect> lines) =>
      AyahBoundEntity(ayah: ayah, lines: lines);

  AyahHighlightPainter buildPainter(List<AyahBoundEntity> ayahs) =>
      AyahHighlightPainter(
        ayahs: ayahs,
        highlightedAyah: ayah,
        prevHighlightedAyah: null,
        playingAyah: null,
        prevPlayingAyah: null,
        highlightColor: const Color(0xFF00FF00),
        playingColor: const Color(0xFFFF0000),
        animationValue: 1.0,
      );

  test('three vertically-adjacent line-rects render as ONE merged path', () {
    final canvas = _RecordingCanvas();
    when(() => canvas.drawPath(any(), any())).thenReturn(null);
    when(() => canvas.drawRRect(any(), any())).thenReturn(null);

    final painter = buildPainter([
      boundWith(const [
        NormalizedRect(x: 0.1, y: 0.10, w: 0.8, h: 0.05),
        NormalizedRect(x: 0.1, y: 0.15, w: 0.8, h: 0.05),
        NormalizedRect(x: 0.1, y: 0.20, w: 0.8, h: 0.05),
      ]),
    ]);

    painter.paint(canvas, size);

    verify(() => canvas.drawPath(any(), any())).called(1);
    verifyNever(() => canvas.drawRRect(any(), any()));
  });

  test('vertical gap between lines splits into TWO merged paths', () {
    final canvas = _RecordingCanvas();
    when(() => canvas.drawPath(any(), any())).thenReturn(null);

    final painter = buildPainter([
      boundWith(const [
        NormalizedRect(x: 0.1, y: 0.10, w: 0.8, h: 0.05),
        // Big vertical gap below (avgHeight*0.3 threshold is 0.015; gap is 0.25)
        NormalizedRect(x: 0.1, y: 0.40, w: 0.8, h: 0.05),
      ]),
    ]);

    painter.paint(canvas, size);

    verify(() => canvas.drawPath(any(), any())).called(2);
  });

  test('rule applies to playing-highlight as well as user-highlight', () {
    final canvas = _RecordingCanvas();
    when(() => canvas.drawPath(any(), any())).thenReturn(null);

    final painter = AyahHighlightPainter(
      ayahs: [
        boundWith(const [
          NormalizedRect(x: 0.1, y: 0.10, w: 0.8, h: 0.05),
          NormalizedRect(x: 0.1, y: 0.15, w: 0.8, h: 0.05),
        ]),
      ],
      highlightedAyah: null,
      prevHighlightedAyah: null,
      playingAyah: ayah,
      prevPlayingAyah: null,
      highlightColor: const Color(0xFF00FF00),
      playingColor: const Color(0xFFFF0000),
      animationValue: 1.0,
    );

    painter.paint(canvas, size);

    verify(() => canvas.drawPath(any(), any())).called(1);
  });
}
