import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart';

import '../../../../config/theme/typography_styles.dart';
import '../../../../core/constants/assets_dir.dart';
import '../../../../core/localization/pending_s.dart';
import '../../../surah/presentation/utils/mushaf_grid.dart';
import '../../../surah/presentation/utils/mushaf_paper_colors.dart';
import '../../domain/entities/share_card_content.dart';
import 'share_card_layout.dart';

typedef ShareImageLoader = Future<ui.Image> Function(String asset);

Future<ui.Image> loadAssetImage(String asset) async {
  final buffer = await ui.ImmutableBuffer.fromAsset(asset);
  final codec = await ui.instantiateImageCodecFromBuffer(buffer);
  try {
    return (await codec.getNextFrame()).image;
  } finally {
    codec.dispose();
  }
}

Rect? alphaBounds(List<ByteData> layers, int width, int height) {
  var minX = width;
  var minY = height;
  var maxX = -1;
  var maxY = -1;
  for (var y = 0; y < height; y++) {
    for (var x = 0; x < width; x++) {
      final at = (y * width + x) * 4 + 3;
      if (layers.every((layer) => layer.getUint8(at) <= 8)) continue;
      minX = math.min(minX, x);
      minY = math.min(minY, y);
      maxX = math.max(maxX, x);
      maxY = math.max(maxY, y);
    }
  }
  if (maxX < 0) return null;
  return Rect.fromLTRB(
    minX.toDouble(),
    minY.toDouble(),
    maxX + 1.0,
    maxY + 1.0,
  );
}

int peakAlpha(ByteData rgba) {
  var peak = 0;
  for (var at = 3; at < rgba.lengthInBytes; at += 4) {
    peak = math.max(peak, rgba.getUint8(at));
  }
  return peak;
}

TextStyle tafsirBodyStyle(String body) =>
    (body.length > 600 ? TS.regular12 : TS.regular14).copyWith(height: 1.8);

class ShareCardCrops {
  ShareCardCrops({
    required this.layout,
    required this.pieces,
    required this.basmalaOpacity,
  });

  final ShareCardLayout layout;
  final List<({ShareCardSlice slice, ui.Image image})> pieces;
  final double basmalaOpacity;
  var _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    for (final piece in pieces) {
      piece.image.dispose();
    }
  }
}

Future<ui.Image> _cut(ui.Image source, Rect src) {
  final width = src.width.round();
  final height = src.height.round();
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawImageRect(
    source,
    src,
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint(),
  );
  final picture = recorder.endRecording();
  final image = picture.toImage(width, height);
  picture.dispose();
  return image;
}

String _assetOf(ShareCardSlice slice) => slice.layer == ShareCardLayer.accent
    ? AssetsDir.mushafPageAccent(slice.page)
    : AssetsDir.mushafPage(slice.page);

Future<ByteData> _rgba(ui.Image image) async => (await image.toByteData())!;

const shareCardTextWidth = (shareCardWidth - 2 * shareCardMargin) / 3;

void paintCardPieces(
  Canvas canvas,
  ShareCardCrops crops,
  MushafPaperColors colors,
) {
  for (final (:slice, :image) in crops.pieces) {
    final tint = switch (slice.layer) {
      ShareCardLayer.ink => colors.ink,
      ShareCardLayer.accent => colors.accent,
      ShareCardLayer.basmala => colors.ink.withValues(
        alpha: crops.basmalaOpacity,
      ),
    };
    canvas.drawImageRect(
      image,
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble()),
      slice.dst,
      Paint()
        ..filterQuality = FilterQuality.high
        ..colorFilter = ColorFilter.mode(tint, BlendMode.srcIn),
    );
  }
}

TextPainter layoutTafsirHeading(MushafPaperColors colors) => TextPainter(
  text: TextSpan(
    text: PendingS.forLanguage('ar').tafsir_muyassar,
    style: TS.bold14.copyWith(color: colors.accent),
  ),
  textAlign: TextAlign.center,
  textDirection: TextDirection.rtl,
)..layout(minWidth: shareCardTextWidth, maxWidth: shareCardTextWidth);

({TextPainter heading, TextPainter body}) layoutTafsirBlock(
  String body,
  MushafPaperColors colors,
  TextStyle style,
) {
  final heading = layoutTafsirHeading(colors);
  final text = TextPainter(
    text: TextSpan(
      text: body,
      style: style.copyWith(color: colors.ink2),
    ),
    textAlign: TextAlign.right,
    textDirection: TextDirection.rtl,
  )..layout(minWidth: shareCardTextWidth, maxWidth: shareCardTextWidth);
  return (heading: heading, body: text);
}

const shareCardTafsirRuleGap = 36.0;
const shareCardTafsirHeadingGap = 8.0;

double tafsirBlockHeight(({TextPainter heading, TextPainter body}) block) =>
    shareCardTafsirRuleGap +
    3 * (block.heading.height + shareCardTafsirHeadingGap + block.body.height);

void paintTafsirBlock(
  Canvas canvas,
  double top,
  ({TextPainter heading, TextPainter body}) block,
  MushafPaperColors colors,
) {
  final line = Paint()
    ..color = colors.accent.withAlpha(150)
    ..strokeWidth = 2;
  const center = shareCardWidth / 2;
  const inset = shareCardMargin + 120;
  canvas
    ..drawLine(Offset(inset, top), Offset(center - 22, top), line)
    ..drawLine(
      Offset(center + 22, top),
      Offset(shareCardWidth - inset, top),
      line,
    )
    ..drawPath(
      Path()
        ..moveTo(center, top - 9)
        ..lineTo(center + 9, top)
        ..lineTo(center, top + 9)
        ..lineTo(center - 9, top)
        ..close(),
      Paint()..color = colors.accent.withAlpha(200),
    )
    ..save()
    ..translate(shareCardMargin, top + shareCardTafsirRuleGap)
    ..scale(3);
  block.heading.paint(canvas, Offset.zero);
  block.body.paint(
    canvas,
    Offset(0, block.heading.height + shareCardTafsirHeadingGap),
  );
  canvas.restore();
}

class ShareCardRenderer {
  ShareCardRenderer({ShareImageLoader loadImage = loadAssetImage})
    : _loadImage = loadImage;

  final ShareImageLoader _loadImage;

  Future<ShareCardCrops> prepare(ShareCardContent content) async {
    final slot = headerSlot(
      surah: content.ayah.surah,
      startPage: content.startPage,
      startPageBounds: content.startPageBounds,
    );
    final band = headerBand(slot.line);
    ShareCardLayout layoutWith(Rect header) => shareCardLayout(
      ayah: content.ayah,
      page: content.page,
      pageBounds: content.pageBounds,
      startPage: content.startPage,
      startPageBounds: content.startPageBounds,
      header: (page: slot.page, box: header),
    );

    final inkAsset = AssetsDir.mushafPage(slot.page);
    final accentAsset = AssetsDir.mushafPageAccent(slot.page);
    final wanted = {
      inkAsset: [band],
      accentAsset: [band],
    };
    for (final slice in layoutWith(band).slices.skip(2)) {
      wanted.putIfAbsent(_assetOf(slice), () => []).add(slice.src);
    }

    final owned = <ui.Image>[];
    try {
      final cuts = <String, List<ui.Image>>{};
      for (final MapEntry(key: asset, value: rects) in wanted.entries) {
        final cut = await _cutPage(asset, rects);
        cuts[asset] = cut;
        owned.addAll(cut);
      }

      final inkBand = cuts[inkAsset]!.first;
      final accentBand = cuts[accentAsset]!.first;
      final width = band.width.round();
      final height = band.height.round();
      final box =
          alphaBounds(
            [await _rgba(inkBand), await _rgba(accentBand)],
            width,
            height,
          ) ??
          Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
      final headerInk = await _cut(inkBand, box);
      owned.add(headerInk);
      final headerAccent = await _cut(accentBand, box);
      owned.add(headerAccent);
      inkBand.dispose();
      accentBand.dispose();
      owned
        ..remove(inkBand)
        ..remove(accentBand);

      final layout = layoutWith(box.shift(band.topLeft));
      final next = {inkAsset: 1, accentAsset: 1};
      ui.Image imageFor(int i, ShareCardSlice slice) {
        if (i < 2) return i == 0 ? headerInk : headerAccent;
        final asset = _assetOf(slice);
        final n = next[asset] ?? 0;
        next[asset] = n + 1;
        return cuts[asset]![n];
      }

      final pieces = [
        for (final (i, slice) in layout.slices.indexed)
          (slice: slice, image: imageFor(i, slice)),
      ];
      var basmalaOpacity = shareCardBasmalaOpacity;
      for (final piece in pieces) {
        if (piece.slice.layer != ShareCardLayer.basmala) continue;
        final peak = peakAlpha(await _rgba(piece.image));
        if (peak > 0) {
          basmalaOpacity = math.min(1, shareCardBasmalaOpacity * 255 / peak);
        }
      }
      return ShareCardCrops(
        layout: layout,
        pieces: pieces,
        basmalaOpacity: basmalaOpacity,
      );
    } catch (_) {
      for (final image in owned) {
        image.dispose();
      }
      rethrow;
    }
  }

  Future<List<ui.Image>> _cutPage(String asset, List<Rect> rects) async {
    final page = await _loadImage(asset);
    final cuts = <ui.Image>[];
    try {
      for (final rect in rects) {
        cuts.add(await _cut(page, rect));
      }
      return cuts;
    } catch (_) {
      for (final cut in cuts) {
        cut.dispose();
      }
      rethrow;
    } finally {
      page.dispose();
    }
  }

  Future<Uint8List> compose(
    ShareCardCrops crops, {
    required MushafPaperColors colors,
    String? tafsir,
  }) async {
    final layout = crops.layout;
    final tafsirTop = layout.textBottom + shareCardTafsirGap * layout.pitch;
    ({TextPainter heading, TextPainter body})? block;
    ui.Picture? picture;
    ui.Image? rendered;
    try {
      var contentBottom = layout.textBottom;
      if (tafsir != null) {
        block = layoutTafsirBlock(tafsir, colors, tafsirBodyStyle(tafsir));
        contentBottom = tafsirTop + tafsirBlockHeight(block);
      }
      final frame = shareCardFrame(contentBottom);
      final k = frame.height > shareCardMaxHeight
          ? shareCardMaxHeight / frame.height
          : 1.0;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..drawPaint(Paint()..color = colors.background)
        ..scale(k)
        ..translate(0, frame.dy);
      paintCardPieces(canvas, crops, colors);
      if (block != null) paintTafsirBlock(canvas, tafsirTop, block, colors);
      picture = recorder.endRecording();
      rendered = await picture.toImage(
        (shareCardWidth * k).round(),
        (frame.height * k).round(),
      );
      final png = (await rendered.toByteData(format: ui.ImageByteFormat.png))!;
      return png.buffer.asUint8List();
    } finally {
      block?.heading.dispose();
      block?.body.dispose();
      picture?.dispose();
      rendered?.dispose();
    }
  }
}
