import 'dart:math' as math;
import 'dart:ui';

import '../../domain/entities/ayah_bound_entity.dart';
import '../../domain/entities/normalized_rect.dart';
import 'reader_rules.dart';

const mushafGridTop = 1536 * 1.82 * 0.058;
const mushafLineHeight = 1536 * 1.82 * (1 - 0.058 - 0.033) / 15;
const mushafColumnWidth = (0.8975 - 0.1043) * 1536;
const mushafOuterPad = 48.0;
const mushafRosetteBleed = 28.0;

typedef MushafLine = ({int page, int line});
typedef RowEdges = ({double left, double right, bool leftOpen, bool rightOpen});

int gridLineOf(NormalizedRect rect) =>
    (((rect.y + rect.h) * mushafPageSize.height - mushafGridTop) /
            mushafLineHeight)
        .round() -
    1;

({int top, int bottom}) gridBand(int line) => (
  top: (mushafGridTop + line * mushafLineHeight).floor(),
  bottom: (mushafGridTop + (line + 1) * mushafLineHeight).floor(),
);

Rect headerBand(int line) {
  final band = gridBand(line);
  return Rect.fromLTRB(
    0,
    band.top - 3.0,
    mushafPageSize.width,
    band.bottom + 3.0,
  );
}

MushafLine headerSlot({
  required int surah,
  required int startPage,
  required List<AyahBoundEntity> startPageBounds,
}) {
  AyahBoundEntity? anchor;
  for (final ayah in [0, 1]) {
    for (final entry in startPageBounds) {
      if (entry.ayah.surah == surah && entry.ayah.ayah == ayah) {
        anchor = entry;
        break;
      }
    }
    if (anchor != null) break;
  }
  final line = gridLineOf(anchor!.lines.first) - 1;
  return line < 0
      ? (page: startPage - 1, line: 14)
      : (page: startPage, line: line);
}

RowEdges rowEdges(NormalizedRect rect, List<NormalizedRect> pageRects) {
  const tol = 0.002;
  final line = gridLineOf(rect);
  var x0 = rect.x;
  var x1 = rect.x + rect.w;
  final centre = (x0 + x1) / 2;
  var leftOpen = true;
  var rightOpen = true;
  for (final o in pageRects) {
    if (o == rect || gridLineOf(o) != line) continue;
    if ((o.x + o.x + o.w) / 2 > centre) {
      if (o.x <= x1 + tol) {
        rightOpen = false;
        if (o.x >= rect.x && o.w < rect.w) x1 = math.min(x1, o.x);
      }
    } else if (o.x + o.w >= rect.x - tol) {
      leftOpen = false;
      if (o.x + o.w <= rect.x + rect.w && o.w < rect.w) {
        x0 = math.max(x0, o.x + o.w);
      }
    }
  }
  final w = mushafPageSize.width;
  return (
    left: x0 * w,
    right: x1 * w,
    leftOpen: leftOpen,
    rightOpen: rightOpen,
  );
}

Rect rowSource(NormalizedRect rect, RowEdges edges) {
  final height = mushafPageSize.height;
  final top = gridLineOf(rect) == 0
      ? (rect.y + rect.h) * height - mushafLineHeight
      : rect.y * height;
  return Rect.fromLTRB(
    (edges.left - (edges.leftOpen ? mushafOuterPad : 0)).roundToDouble(),
    top.roundToDouble(),
    (edges.right + (edges.rightOpen ? mushafOuterPad : 0)).roundToDouble(),
    (top + mushafLineHeight).roundToDouble(),
  );
}

Rect accentSource(NormalizedRect rect, RowEdges edges) {
  final src = rowSource(rect, edges);
  final band = gridBand(gridLineOf(rect));
  return Rect.fromLTRB(
    edges.leftOpen ? src.left : src.left - mushafRosetteBleed,
    math.max(src.top, band.top.toDouble()),
    edges.rightOpen ? src.right : src.right - mushafRosetteBleed,
    math.min(src.bottom, band.bottom.toDouble()),
  );
}
