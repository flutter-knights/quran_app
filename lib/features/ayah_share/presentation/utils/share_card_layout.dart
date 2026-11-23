import 'dart:math' as math;
import 'dart:ui';

import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../surah/domain/entities/ayah_bound_entity.dart';
import '../../../surah/domain/entities/normalized_rect.dart';
import '../../../surah/presentation/utils/mushaf_grid.dart';
import '../../../surah/presentation/utils/reader_rules.dart';

const shareCardWidth = 1080.0;
const shareCardMargin = 72.0;
const shareCardMaxHeight = 4096.0;
const shareCardTafsirGap = 0.55;
const shareCardBasmalaOpacity = 0.42;

const _topPad = 72.0;
const _bottomPad = 80.0;
const _headerMargin = 56.0;
const _headerGap = 0.55;
const _basmalaScale = 0.78;
const _basmalaGap = 0.45;
const _minHeight = 0.62 * shareCardWidth;
const _tailMax = 100.0;
const _refit = 1.02;

enum ShareCardLayer { ink, accent, basmala }

class ShareCardSlice extends Equatable {
  const ShareCardSlice({
    required this.layer,
    required this.page,
    required this.src,
    required this.dst,
  });

  final ShareCardLayer layer;
  final int page;
  final Rect src;
  final Rect dst;

  @override
  List<Object> get props => [layer, page, src, dst];
}

typedef ShareCardRow = ({double coreLeft, double coreRight, double top});

class ShareCardLayout {
  const ShareCardLayout({
    required this.slices,
    required this.rows,
    required this.scale,
    required this.headerScale,
    required this.textBottom,
    required this.mergedTail,
  });

  final List<ShareCardSlice> slices;
  final List<ShareCardRow> rows;
  final double scale;
  final double headerScale;
  final double textBottom;
  final bool mergedTail;

  double get pitch => mushafLineHeight * scale;
}

typedef _Piece = ({NormalizedRect rect, RowEdges edges, Rect src, double core});

_Piece _piece(NormalizedRect rect, List<NormalizedRect> pageRects) {
  final edges = rowEdges(rect, pageRects);
  final src = rowSource(rect, edges);
  final pad =
      (edges.leftOpen ? mushafOuterPad : 0) +
      (edges.rightOpen ? mushafOuterPad : 0);
  return (rect: rect, edges: edges, src: src, core: src.width - pad);
}

Rect _place(Rect src, bool leftOpen, double leftCard, double top, double s) {
  final origin = src.left + (leftOpen ? mushafOuterPad : 0);
  return Rect.fromLTRB(
    leftCard + (src.left - origin) * s,
    top,
    leftCard + (src.right - origin) * s,
    top + src.height * s,
  );
}

ShareCardLayout shareCardLayout({
  required AyahIdentifier ayah,
  required int page,
  required List<AyahBoundEntity> pageBounds,
  required int startPage,
  required List<AyahBoundEntity> startPageBounds,
  required ({int page, Rect box}) header,
}) {
  final pageRects = [for (final b in pageBounds) ...b.lines];
  final pieces = [
    for (final rect in pageBounds.firstWhere((b) => b.ayah == ayah).lines)
      _piece(rect, pageRects),
  ];
  final tail =
      pieces.length > 1 &&
          pieces.last.core < _tailMax &&
          pieces.last.edges.rightOpen
      ? pieces.removeLast()
      : null;
  final widths = [
    for (final (i, p) in pieces.indexed)
      p.core + (i == pieces.length - 1 ? tail?.core ?? 0 : 0),
  ];
  final widest = widths.reduce(math.max);
  final scale =
      (shareCardWidth - 2 * shareCardMargin) /
      (widest > mushafColumnWidth * _refit ? widest : mushafColumnWidth);
  final pitch = mushafLineHeight * scale;

  final slices = <ShareCardSlice>[];
  var y = _topPad;

  final box = header.box;
  final headerScale = math.min(
    scale,
    (shareCardWidth - 2 * _headerMargin) / box.width,
  );
  final headerDst = Rect.fromLTWH(
    (shareCardWidth - box.width * headerScale) / 2,
    y,
    box.width * headerScale,
    box.height * headerScale,
  );
  for (final layer in [ShareCardLayer.ink, ShareCardLayer.accent]) {
    slices.add(
      ShareCardSlice(layer: layer, page: header.page, src: box, dst: headerDst),
    );
  }
  y += box.height * headerScale + _headerGap * pitch;

  if (ayah.surah != 1 && ayah.surah != 9) {
    final rect = startPageBounds
        .firstWhere((b) => b.ayah.surah == ayah.surah && b.ayah.ayah == 0)
        .lines
        .first;
    final src = rowSource(rect, (
      left: rect.x * mushafPageSize.width,
      right: (rect.x + rect.w) * mushafPageSize.width,
      leftOpen: false,
      rightOpen: false,
    ));
    final bs = _basmalaScale * scale;
    slices.add(
      ShareCardSlice(
        layer: ShareCardLayer.basmala,
        page: startPage,
        src: src,
        dst: Rect.fromLTWH(
          (shareCardWidth - src.width * bs) / 2,
          y,
          src.width * bs,
          src.height * bs,
        ),
      ),
    );
    y += mushafLineHeight * bs + _basmalaGap * pitch;
  }

  final centred = page <= 2 || pieces.length == 1;
  final rows = <ShareCardRow>[];
  for (final (i, piece) in pieces.indexed) {
    final top = y + i * pitch;
    final carriesTail = tail != null && i == pieces.length - 1;
    final width = widths[i] * scale;
    final right = centred
        ? (shareCardWidth + width) / 2
        : shareCardWidth - shareCardMargin;
    final pieceLeft = right - piece.core * scale;
    rows.add((coreLeft: right - width, coreRight: right, top: top));
    slices.add(
      ShareCardSlice(
        layer: ShareCardLayer.ink,
        page: page,
        src: piece.src,
        dst: _place(piece.src, piece.edges.leftOpen, pieceLeft, top, scale),
      ),
    );
    var accentPiece = piece;
    var accentLeft = pieceLeft;
    if (carriesTail) {
      final tailLeft = pieceLeft - tail.core * scale;
      slices.add(
        ShareCardSlice(
          layer: ShareCardLayer.ink,
          page: page,
          src: tail.src,
          dst: _place(tail.src, tail.edges.leftOpen, tailLeft, top, scale),
        ),
      );
      accentPiece = tail;
      accentLeft = tailLeft;
    }
    if (i == pieces.length - 1) {
      final accent = accentSource(accentPiece.rect, accentPiece.edges);
      final origin =
          accentPiece.src.left +
          (accentPiece.edges.leftOpen ? mushafOuterPad : 0);
      slices.add(
        ShareCardSlice(
          layer: ShareCardLayer.accent,
          page: page,
          src: accent,
          dst: Rect.fromLTRB(
            accentLeft + (accent.left - origin) * scale,
            top + (accent.top - accentPiece.src.top) * scale,
            accentLeft + (accent.right - origin) * scale,
            top + (accent.bottom - accentPiece.src.top) * scale,
          ),
        ),
      );
    }
  }

  return ShareCardLayout(
    slices: slices,
    rows: rows,
    scale: scale,
    headerScale: headerScale,
    textBottom: y + pieces.length * pitch,
    mergedTail: tail != null,
  );
}

({int height, double dy}) shareCardFrame(double contentBottom) {
  final content = contentBottom + _bottomPad;
  final height = math.max(content, _minHeight).round();
  return (height: height, dy: (height - content) / 2);
}
