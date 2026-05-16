import 'package:flutter/material.dart';

import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../domain/entities/ayah_bound_entity.dart';
import '../../../../domain/entities/normalized_rect.dart';

class AyahHighlightPainter extends CustomPainter {
  AyahHighlightPainter({
    required this.ayahs,
    required this.highlightedAyah,
    required this.playingAyah,
    required this.highlightColor,
    required this.playingColor,
    required this.animationValue,
  });

  final List<AyahBoundEntity> ayahs;
  final AyahIdentifier? highlightedAyah;
  final AyahIdentifier? playingAyah;
  final Color highlightColor;
  final Color playingColor;
  final double animationValue;

  @override
  void paint(Canvas canvas, Size size) {
    if (playingAyah != null) {
      _paintFor(canvas, size, playingAyah!,
          playingColor.withValues(alpha: 0.15 * animationValue));
    }
    if (highlightedAyah != null) {
      _paintFor(canvas, size, highlightedAyah!,
          highlightColor.withValues(alpha: 0.25 * animationValue));
    }
  }

  void _paintFor(
      Canvas canvas, Size size, AyahIdentifier key, Color color) {
    final paint = Paint()..color = color;
    for (final bound in ayahs) {
      if (bound.ayah != key) continue;
      for (final r in bound.lines) {
        final rect = _denormalize(r, size);
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(6)),
          paint,
        );
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
        old.playingAyah != playingAyah ||
        old.animationValue != animationValue ||
        old.highlightColor != highlightColor ||
        old.playingColor != playingColor ||
        !identical(old.ayahs, ayahs);
  }
}
