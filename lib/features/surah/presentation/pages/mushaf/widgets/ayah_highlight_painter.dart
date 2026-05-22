import 'package:flutter/material.dart';

import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../domain/entities/ayah_bound_entity.dart';
import '../../../../domain/entities/normalized_rect.dart';

class AyahHighlightPainter extends CustomPainter {
  AyahHighlightPainter({
    required this.ayahs,
    required this.highlightedAyah,
    required this.prevHighlightedAyah,
    required this.playingAyah,
    required this.prevPlayingAyah,
    required this.highlightColor,
    required this.playingColor,
    required this.animationValue,
  });

  final List<AyahBoundEntity> ayahs;
  final AyahIdentifier? highlightedAyah;
  final AyahIdentifier? prevHighlightedAyah;
  final AyahIdentifier? playingAyah;
  final AyahIdentifier? prevPlayingAyah;
  final Color highlightColor;
  final Color playingColor;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    // Outgoing: fade out as animationValue goes 0 → 1
    if (prevPlayingAyah != null) {
      _paintFor(canvas, size, prevPlayingAyah!,
          playingColor.withValues(alpha: 0.15 * (1 - animationValue)));
    }
    if (prevHighlightedAyah != null) {
      _paintFor(canvas, size, prevHighlightedAyah!,
          highlightColor.withValues(alpha: 0.20 * (1 - animationValue)));
    }
    // Incoming: fade in as animationValue goes 0 → 1
    if (playingAyah != null) {
      _paintFor(canvas, size, playingAyah!,
          playingColor.withValues(alpha: 0.15 * animationValue));
    }
    if (highlightedAyah != null) {
      _paintFor(canvas, size, highlightedAyah!,
          highlightColor.withValues(alpha: 0.20 * animationValue));
    }
  }

  void _paintFor(
      Canvas canvas, Size size, AyahIdentifier key, Color fillColor) {
    final paint = Paint()..color = fillColor;
    for (final bound in ayahs) {
      if (bound.ayah != key) continue;
      for (final line in bound.lines) {
        canvas.drawRect(_denormalize(line, size), paint);
      }
    }
  }

  Rect _denormalize(NormalizedRect r, Size size) {
    return Rect.fromLTWH(
      r.x * size.width,
      r.y * size.height,
      r.w * size.width,
      r.h * size.height,
    );
  }

  @override
  bool shouldRepaint(AyahHighlightPainter old) {
    return old.highlightedAyah != highlightedAyah ||
        old.prevHighlightedAyah != prevHighlightedAyah ||
        old.playingAyah != playingAyah ||
        old.prevPlayingAyah != prevPlayingAyah ||
        old.animationValue != animationValue ||
        old.highlightColor != highlightColor ||
        old.playingColor != playingColor ||
        !identical(old.ayahs, ayahs);
  }
}
