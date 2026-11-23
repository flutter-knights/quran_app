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
  final data = await rootBundle.load(asset);
  final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
  final frame = await codec.getNextFrame();
  codec.dispose();
  return frame.image;
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

  void dispose() {
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

Future<ByteData> _rgba(ui.Image image) async => (await image.toByteData())!;

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
    final inkBand = await _cutPage(AssetsDir.mushafPage(slot.page), [band]);
    final accentBand = await _cutPage(AssetsDir.mushafPageAccent(slot.page), [
      band,
    ]);
    final width = band.width.round();
    final height = band.height.round();
    final box =
        alphaBounds(
          [await _rgba(inkBand.single), await _rgba(accentBand.single)],
          width,
          height,
        ) ??
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
    final headerInk = await _cut(inkBand.single, box);
    final headerAccent = await _cut(accentBand.single, box);
    inkBand.single.dispose();
    accentBand.single.dispose();

    final layout = shareCardLayout(
      ayah: content.ayah,
      page: content.page,
      pageBounds: content.pageBounds,
      startPage: content.startPage,
      startPageBounds: content.startPageBounds,
      header: (page: slot.page, box: box.shift(band.topLeft)),
    );

    final images = <int, ui.Image>{0: headerInk, 1: headerAccent};
    final byAsset = <String, List<int>>{};
    for (var i = 2; i < layout.slices.length; i++) {
      final slice = layout.slices[i];
      final asset = slice.layer == ShareCardLayer.accent
          ? AssetsDir.mushafPageAccent(slice.page)
          : AssetsDir.mushafPage(slice.page);
      byAsset.putIfAbsent(asset, () => []).add(i);
    }
    for (final MapEntry(key: asset, value: indices) in byAsset.entries) {
      final cuts = await _cutPage(asset, [
        for (final i in indices) layout.slices[i].src,
      ]);
      for (final (n, i) in indices.indexed) {
        images[i] = cuts[n];
      }
    }

    final pieces = [
      for (final (i, slice) in layout.slices.indexed)
        (slice: slice, image: images[i]!),
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
  }

  Future<List<ui.Image>> _cutPage(String asset, List<Rect> rects) async {
    final page = await _loadImage(asset);
    final cuts = [for (final rect in rects) await _cut(page, rect)];
    page.dispose();
    return cuts;
  }

  Future<Uint8List> compose(
    ShareCardCrops crops, {
    required MushafPaperColors colors,
    String? tafsir,
  }) async {
    final layout = crops.layout;
    const textWidth = (shareCardWidth - 2 * shareCardMargin) / 3;
    final tafsirTop = layout.textBottom + shareCardTafsirGap * layout.pitch;
    TextPainter? heading;
    TextPainter? body;
    var contentBottom = layout.textBottom;
    if (tafsir != null) {
      heading = TextPainter(
        text: TextSpan(
          text: PendingS.forLanguage('ar').tafsir_muyassar,
          style: TS.bold14.copyWith(color: colors.accent),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.rtl,
      )..layout(minWidth: textWidth, maxWidth: textWidth);
      body = TextPainter(
        text: TextSpan(
          text: tafsir,
          style: tafsirBodyStyle(tafsir).copyWith(color: colors.ink2),
        ),
        textAlign: TextAlign.right,
        textDirection: TextDirection.rtl,
      )..layout(minWidth: textWidth, maxWidth: textWidth);
      contentBottom = tafsirTop + 36 + 3 * (heading.height + 8 + body.height);
    }
    final frame = shareCardFrame(contentBottom);
    final k = frame.height > shareCardMaxHeight
        ? shareCardMaxHeight / frame.height
        : 1.0;

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)..scale(k);
    canvas.drawRect(
      Rect.fromLTWH(0, 0, shareCardWidth, frame.height.toDouble()),
      Paint()..color = colors.background,
    );
    canvas.translate(0, frame.dy);
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
    if (heading != null && body != null) {
      final line = Paint()
        ..color = colors.accent.withAlpha(150)
        ..strokeWidth = 2;
      const center = shareCardWidth / 2;
      const inset = shareCardMargin + 120;
      canvas
        ..drawLine(
          Offset(inset, tafsirTop),
          Offset(center - 22, tafsirTop),
          line,
        )
        ..drawLine(
          Offset(center + 22, tafsirTop),
          Offset(shareCardWidth - inset, tafsirTop),
          line,
        )
        ..drawPath(
          Path()
            ..moveTo(center, tafsirTop - 9)
            ..lineTo(center + 9, tafsirTop)
            ..lineTo(center, tafsirTop + 9)
            ..lineTo(center - 9, tafsirTop)
            ..close(),
          Paint()..color = colors.accent.withAlpha(200),
        )
        ..save()
        ..translate(shareCardMargin, tafsirTop + 36)
        ..scale(3);
      heading.paint(canvas, Offset.zero);
      body.paint(canvas, Offset(0, heading.height + 8));
      canvas.restore();
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(
      (shareCardWidth * k).round(),
      (frame.height * k).round(),
    );
    picture.dispose();
    final png = (await image.toByteData(format: ui.ImageByteFormat.png))!;
    image.dispose();
    heading?.dispose();
    body?.dispose();
    return png.buffer.asUint8List();
  }
}
