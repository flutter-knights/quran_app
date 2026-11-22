import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:quran_app/core/constants/assets_dir.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';
import 'package:quran_app/features/surah/presentation/utils/ayah_strip_layout.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

class AyahStrip extends StatefulWidget {
  const AyahStrip({
    super.key,
    required this.page,
    required this.lines,
    required this.colors,
    this.imageFor,
  });

  final int page;
  final List<NormalizedRect> lines;
  final MushafPaperColors colors;
  final ImageProvider Function(int cacheWidth)? imageFor;

  @override
  State<AyahStrip> createState() => _AyahStripState();
}

class _AyahStripState extends State<AyahStrip> {
  ImageInfo? _info;
  ImageStream? _stream;
  late final ImageStreamListener _listener = ImageStreamListener(_onImage);
  double? _resolvedKey;

  void _onImage(ImageInfo info, bool synchronousCall) {
    _info?.dispose();
    _info = info;
    if (mounted) setState(() {});
  }

  void _release() {
    _stream?.removeListener(_listener);
    _stream = null;
    _info?.dispose();
    _info = null;
    _resolvedKey = null;
  }

  void _resolve(double width, double dpr) {
    if (!mounted || _resolvedKey != width) return;
    final cacheWidth = ayahStripCacheWidth(width, dpr);
    final provider =
        widget.imageFor?.call(cacheWidth) ??
        ResizeImage(
          AssetImage(AssetsDir.mushafPage(widget.page)),
          width: cacheWidth,
        );
    _stream = provider.resolve(ImageConfiguration.empty)
      ..addListener(_listener);
  }

  @override
  void didUpdateWidget(AyahStrip old) {
    super.didUpdateWidget(old);
    if (old.page != widget.page) _release();
  }

  @override
  void dispose() {
    _stream?.removeListener(_listener);
    _info?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.lines.isEmpty) return const SizedBox.shrink();
    final dpr = MediaQuery.devicePixelRatioOf(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final layout = ayahStripLayout(
          lines: widget.lines,
          image: ayahStripPageSize,
          width: width,
        );
        if (_resolvedKey != width) {
          _release();
          _resolvedKey = width;
          WidgetsBinding.instance.addPostFrameCallback(
            (_) => _resolve(width, dpr),
          );
        }
        return Semantics(
          image: true,
          excludeSemantics: true,
          child: SizedBox(
            width: width,
            height: layout.height,
            child: CustomPaint(
              key: const ValueKey('ayah-strip-paint'),
              painter: AyahStripPainter(
                image: _info?.image,
                slices: layout.slices,
                colors: widget.colors,
              ),
            ),
          ),
        );
      },
    );
  }
}

@visibleForTesting
class AyahStripPainter extends CustomPainter {
  AyahStripPainter({
    required this.image,
    required this.slices,
    required this.colors,
  });

  final ui.Image? image;
  final List<({Rect src, Rect dst})> slices;
  final MushafPaperColors colors;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.drawRect(Offset.zero & size, Paint()..color = colors.background);
    final image = this.image;
    if (image == null) return;
    final k = image.width / ayahStripPageSize.width;
    final paint = Paint()
      ..colorFilter = ColorFilter.mode(colors.ink, BlendMode.srcIn)
      ..filterQuality = FilterQuality.medium;
    for (final s in slices) {
      final src = s.src;
      canvas.drawImageRect(
        image,
        Rect.fromLTRB(src.left * k, src.top * k, src.right * k, src.bottom * k),
        s.dst,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(AyahStripPainter old) =>
      old.image != image ||
      old.colors != colors ||
      !listEquals(old.slices, slices);
}
