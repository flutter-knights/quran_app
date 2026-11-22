import 'dart:math' as math;
import 'dart:ui';

import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';
import 'package:quran_app/features/surah/presentation/utils/reader_rules.dart';

const ayahStripMaxLines = 3;
const ayahStripFullLine = .8;

({List<({Rect src, Rect dst})> slices, double height}) ayahStripLayout({
  required List<NormalizedRect> lines,
  required Size image,
  required double width,
}) {
  final taken = lines.take(ayahStripMaxLines).toList();
  if (taken.isEmpty || !width.isFinite || width <= 0) {
    return (slices: const [], height: 0);
  }
  final widest = taken.map((l) => l.w).reduce(math.max);
  if (widest <= 0) return (slices: const [], height: 0);
  final scale = width / (math.max(widest, ayahStripFullLine) * image.width);
  final slices = <({Rect src, Rect dst})>[];
  var top = 0.0;
  for (final l in taken) {
    final w = l.w * image.width;
    final h = l.h * image.height;
    slices.add((
      src: Rect.fromLTWH(l.x * image.width, l.y * image.height, w, h),
      dst: Rect.fromLTWH(width - w * scale, top, w * scale, h * scale),
    ));
    top += h * scale;
  }
  return (slices: slices, height: top);
}

int ayahStripCacheWidth(double width, double devicePixelRatio) => math.min(
  mushafPageSize.width.toInt(),
  (width * devicePixelRatio / ayahStripFullLine).ceil(),
);
