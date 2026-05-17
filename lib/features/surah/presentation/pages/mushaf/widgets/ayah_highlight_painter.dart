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

  static const double _radius = 6.0;

  @override
  void paint(Canvas canvas, Size size) {
    // Outgoing: fade out as animationValue goes 0 → 1
    if (prevPlayingAyah != null) {
      _paintFor(canvas, size, prevPlayingAyah!,
          playingColor.withValues(alpha: 0.30 * (1 - animationValue)));
    }
    if (prevHighlightedAyah != null) {
      _paintFor(canvas, size, prevHighlightedAyah!,
          highlightColor.withValues(alpha: 0.45 * (1 - animationValue)));
    }
    // Incoming: fade in as animationValue goes 0 → 1
    if (playingAyah != null) {
      _paintFor(canvas, size, playingAyah!,
          playingColor.withValues(alpha: 0.30 * animationValue));
    }
    if (highlightedAyah != null) {
      _paintFor(canvas, size, highlightedAyah!,
          highlightColor.withValues(alpha: 0.45 * animationValue));
    }
  }

  void _paintFor(
      Canvas canvas, Size size, AyahIdentifier key, Color fillColor) {
    for (final bound in ayahs) {
      if (bound.ayah != key) continue;
      final sorted = bound.lines
          .map((r) => _denormalize(r, size))
          .toList()
        ..sort((a, b) => a.top.compareTo(b.top));
      for (final group in _groupAdjacentRects(sorted)) {
        canvas.drawPath(
          _buildMergedPath(group, _radius),
          Paint()..color = fillColor,
        );
      }
    }
  }

  // Split into segments where consecutive rects have a visible gap.
  List<List<Rect>> _groupAdjacentRects(List<Rect> sorted) {
    if (sorted.isEmpty) return [];
    final groups = <List<Rect>>[];
    var current = [sorted.first];
    for (int i = 1; i < sorted.length; i++) {
      final prev = sorted[i - 1];
      final curr = sorted[i];
      final avgHeight = (prev.height + curr.height) / 2;
      if (curr.top - prev.bottom > avgHeight * 0.3) {
        groups.add(current);
        current = [curr];
      } else {
        current.add(curr);
      }
    }
    groups.add(current);
    return groups;
  }

  Path _buildMergedPath(List<Rect> rects, double radius) {
    if (rects.isEmpty) return Path();
    if (rects.length == 1) {
      return Path()
        ..addRRect(
            RRect.fromRectAndRadius(rects.first, Radius.circular(radius)));
    }

    final first = rects.first;
    final last = rects.last;
    final path = Path();

    // Top-right arc
    path.moveTo(first.right - radius, first.top);
    path.arcToPoint(Offset(first.right, first.top + radius),
        radius: Radius.circular(radius));

    // Right side with step corners
    for (int i = 0; i < rects.length - 1; i++) {
      path.lineTo(rects[i].right, rects[i].bottom);
      path.lineTo(rects[i + 1].right, rects[i + 1].top);
    }

    // Bottom-right arc
    path.lineTo(last.right, last.bottom - radius);
    path.arcToPoint(Offset(last.right - radius, last.bottom),
        radius: Radius.circular(radius));

    // Bottom edge → bottom-left arc
    path.lineTo(last.left + radius, last.bottom);
    path.arcToPoint(Offset(last.left, last.bottom - radius),
        radius: Radius.circular(radius));

    // Left side ascending with step corners
    for (int i = rects.length - 1; i > 0; i--) {
      path.lineTo(rects[i].left, rects[i].top);
      path.lineTo(rects[i - 1].left, rects[i - 1].bottom);
    }

    // Top-left arc
    path.lineTo(first.left, first.top + radius);
    path.arcToPoint(Offset(first.left + radius, first.top),
        radius: Radius.circular(radius));

    path.close();
    return path;
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
