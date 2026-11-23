import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../../../../config/theme/typography_styles.dart';
import '../../../surah/presentation/utils/mushaf_paper_colors.dart';
import 'share_card_layout.dart';
import 'share_card_renderer.dart';

const reelWidth = 1080.0;
const reelHeight = 1920.0;
const reelFooterPad = 24.0;

final reelTafsirStyle = TS.regular12.copyWith(height: 1.8);

typedef ReelFrameGeometry = ({double scale, double tafsirMaxHeight});

ReelFrameGeometry reelFrameGeometry(
  ShareCardLayout layout, {
  required double footerHeight,
  required double headingHeight,
}) {
  final available = reelHeight - footerHeight;
  final block = layout.textBottom + shareCardMargin;
  if (block > available) return (scale: available / block, tafsirMaxHeight: 0);
  final tafsirTop = layout.textBottom + shareCardTafsirGap * layout.pitch;
  return (
    scale: 1,
    tafsirMaxHeight:
        (available - shareCardMargin - tafsirTop - 36) / 3 - headingHeight - 8,
  );
}

String? fitReelTafsir(String body, {required double maxHeight}) {
  final painter = TextPainter(
    textAlign: TextAlign.right,
    textDirection: TextDirection.rtl,
  );
  double heightOf(String text) {
    painter
      ..text = TextSpan(text: text, style: reelTafsirStyle)
      ..layout(maxWidth: shareCardTextWidth);
    return painter.height;
  }

  try {
    painter
      ..text = TextSpan(text: 'ا', style: reelTafsirStyle)
      ..layout();
    if (maxHeight < 3 * painter.preferredLineHeight) return null;
    if (heightOf(body) <= maxHeight) return body;

    String? longest(List<int> ends) {
      var low = 0;
      var high = ends.length - 1;
      String? best;
      while (low <= high) {
        final mid = (low + high) ~/ 2;
        final candidate = '${body.substring(0, ends[mid]).trimRight()} …';
        if (heightOf(candidate) <= maxHeight) {
          best = candidate;
          low = mid + 1;
        } else {
          high = mid - 1;
        }
      }
      return best;
    }

    final whitespace = RegExp(r'\s');
    final sentences = [
      for (var i = 0; i < body.length; i++)
        if (body[i] == '.' &&
            (i + 1 == body.length || whitespace.hasMatch(body[i + 1])))
          i + 1,
    ];
    final words = [
      for (var i = 1; i < body.length; i++)
        if (whitespace.hasMatch(body[i])) i,
    ];
    return longest(sentences) ?? longest(words);
  } finally {
    painter.dispose();
  }
}

class ReelFramePainter {
  Future<Uint8List> paint(
    ShareCardCrops crops, {
    required MushafPaperColors colors,
    required String footer,
    String? tafsir,
  }) async {
    final layout = crops.layout;
    final footerText = TextPainter(
      text: TextSpan(
        text: footer,
        style: TS.regular10.copyWith(color: colors.ink2),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.rtl,
    )..layout(minWidth: shareCardTextWidth, maxWidth: shareCardTextWidth);
    ({TextPainter heading, TextPainter body})? block;
    ui.Picture? picture;
    ui.Image? rendered;
    try {
      final footerHeight = 3 * footerText.height + 2 * reelFooterPad;
      var headingHeight = 0.0;
      if (tafsir != null) {
        final probe = layoutTafsirHeading(colors);
        headingHeight = probe.height;
        probe.dispose();
      }
      final geometry = reelFrameGeometry(
        layout,
        footerHeight: footerHeight,
        headingHeight: headingHeight,
      );
      final fitted = tafsir == null
          ? null
          : fitReelTafsir(tafsir, maxHeight: geometry.tafsirMaxHeight);
      if (fitted != null) {
        block = layoutTafsirBlock(fitted, colors, reelTafsirStyle);
      }
      final tafsirTop = layout.textBottom + shareCardTafsirGap * layout.pitch;
      final available = reelHeight - footerHeight;
      final content = block == null
          ? (layout.textBottom + shareCardMargin) * geometry.scale
          : tafsirTop + tafsirBlockHeight(block) + shareCardMargin;
      final dy = (available - content) / 2;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder)
        ..drawPaint(Paint()..color = colors.background)
        ..save()
        ..translate((reelWidth - reelWidth * geometry.scale) / 2, dy)
        ..scale(geometry.scale);
      paintCardPieces(canvas, crops, colors);
      if (block != null) paintTafsirBlock(canvas, tafsirTop, block, colors);
      canvas
        ..restore()
        ..save()
        ..translate(
          shareCardMargin,
          reelHeight - reelFooterPad - 3 * footerText.height,
        )
        ..scale(3);
      footerText.paint(canvas, Offset.zero);
      canvas.restore();
      picture = recorder.endRecording();
      rendered = await picture.toImage(reelWidth.round(), reelHeight.round());
      final png = (await rendered.toByteData(format: ui.ImageByteFormat.png))!;
      return png.buffer.asUint8List();
    } finally {
      footerText.dispose();
      block?.heading.dispose();
      block?.body.dispose();
      picture?.dispose();
      rendered?.dispose();
    }
  }
}
