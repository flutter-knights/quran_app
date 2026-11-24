import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import '../../domain/entities/ayah_bound_entity.dart';
import '../../domain/entities/normalized_rect.dart';
import 'reader_rules.dart';

const _renderHeight = mushafPageWidth * mushafRenderAspect;
const _topMargin = 0.058;
const _bottomMargin = 0.033;
const mushafGridTop = _renderHeight * _topMargin;
const mushafLineHeight = _renderHeight * (1 - _topMargin - _bottomMargin) / 15;
const mushafColumnWidth = (0.8975 - 0.1043) * mushafPageWidth;
const mushafOuterPad = 48.0;
const mushafRosetteBleed = 28.0;
const mushafInkMargin = 60;
const _riseLimit = 25;
const _dropLimit = 10;

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
  final anchor =
      startPageBounds
          .where((e) => e.ayah.surah == surah && e.ayah.ayah == 0)
          .firstOrNull ??
      startPageBounds.firstWhere(
        (e) => e.ayah.surah == surah && e.ayah.ayah == 1,
      );
  final line = gridLineOf(anchor.lines.first) - 1;
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

Rect lineInkSource(NormalizedRect rect, RowEdges edges) {
  final src = rowSource(rect, edges);
  final band = gridBand(gridLineOf(rect));
  return Rect.fromLTRB(
    src.left,
    (band.top - mushafInkMargin).toDouble(),
    src.right,
    (band.bottom + mushafInkMargin).toDouble(),
  );
}

void keepLineInk(
  ByteData rgba,
  int width, {
  required int line,
  required int top,
}) {
  final pixels = rgba.buffer.asUint32List(
    rgba.offsetInBytes,
    rgba.lengthInBytes ~/ 4,
  );
  final height = pixels.length ~/ width;
  final band = gridBand(line);
  final labels = Int32List(pixels.length);
  final stack = Int32List(pixels.length);
  final tops = <int>[];
  final bottoms = <int>[];

  for (var start = 0; start < pixels.length; start++) {
    if (labels[start] != 0 || !_inked(pixels[start])) continue;
    final id = tops.length + 1;
    var maxY = 0;
    var size = 0;
    labels[start] = id;
    stack[size++] = start;
    while (size > 0) {
      final i = stack[--size];
      final y = i ~/ width;
      final x = i - y * width;
      if (y > maxY) maxY = y;
      final left = x > 0 ? -1 : 0;
      final right = x < width - 1 ? 1 : 0;
      for (var ny = y > 0 ? y - 1 : y; ny <= y + 1 && ny < height; ny++) {
        final row = ny * width + x;
        for (var j = row + left; j <= row + right; j++) {
          if (labels[j] == 0 && _inked(pixels[j])) {
            labels[j] = id;
            stack[size++] = j;
          }
        }
      }
    }
    tops.add(start ~/ width + top);
    bottoms.add(maxY + 1 + top);
  }

  List<bool> belowEdge(int edge) {
    final below = <bool?>[
      for (var c = 0; c < tops.length; c++)
        tops[c] < edge - _riseLimit
            ? false
            : bottoms[c] > edge + _dropLimit
            ? true
            : null,
    ];
    return [
      for (var c = 0; c < below.length; c++)
        below[c] ?? _nearestSide(labels, width, c + 1, below),
    ];
  }

  final underTop = belowEdge(band.top);
  final underBottom = belowEdge(band.bottom);
  for (var i = 0; i < pixels.length; i++) {
    final c = labels[i] - 1;
    if (c >= 0 && !(underTop[c] && !underBottom[c])) pixels[i] = 0;
  }
}

bool _inked(int pixel) => pixel & 0xFF000000 != 0;

void _forNeighbours(int i, int width, int height, void Function(int) visit) {
  final y = i ~/ width;
  final x = i - y * width;
  final x0 = math.max(0, x - 1);
  final x1 = math.min(width - 1, x + 1);
  for (var ny = math.max(0, y - 1); ny <= math.min(height - 1, y + 1); ny++) {
    for (var nx = x0; nx <= x1; nx++) {
      visit(ny * width + nx);
    }
  }
}

bool _nearestSide(Int32List labels, int width, int id, List<bool?> below) {
  final height = labels.length ~/ width;
  final seen = Uint8List(labels.length);
  var ring = <int>[];
  for (var i = 0; i < labels.length; i++) {
    if (labels[i] == id) {
      seen[i] = 1;
      ring.add(i);
    }
  }
  while (ring.isNotEmpty) {
    var under = 0;
    var over = 0;
    final next = <int>[];
    for (final i in ring) {
      _forNeighbours(i, width, height, (j) {
        if (seen[j] == 1) return;
        seen[j] = 1;
        next.add(j);
        final side = labels[j] == 0 ? null : below[labels[j] - 1];
        if (side == true) under++;
        if (side == false) over++;
      });
    }
    if (under + over > 0) return under >= over;
    ring = next;
  }
  return true;
}
