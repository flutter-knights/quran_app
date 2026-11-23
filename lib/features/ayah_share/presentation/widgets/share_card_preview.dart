import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../config/theme/color_scheme.dart';
import '../../../../core/constants/mushaf_paper.dart';
import '../../../surah/presentation/utils/mushaf_paper_colors.dart';
import '../utils/share_card_layout.dart';

class ShareCardPreview extends StatefulWidget {
  const ShareCardPreview({
    super.key,
    required this.bytes,
    required this.paper,
    required this.progress,
    required this.loading,
    required this.semanticLabel,
  });

  final Uint8List? bytes;
  final MushafPaper paper;
  final bool progress;
  final bool loading;
  final String semanticLabel;

  @override
  State<ShareCardPreview> createState() => _ShareCardPreviewState();
}

class _ShareCardPreviewState extends State<ShareCardPreview> {
  static final _radius = BorderRadius.circular(12);

  int? _cacheWidth;

  void _evict(Uint8List? bytes) {
    final width = _cacheWidth;
    if (bytes == null || width == null) return;
    ResizeImage(MemoryImage(bytes), width: width).evict();
  }

  @override
  void didUpdateWidget(ShareCardPreview oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bytes != widget.bytes) _evict(oldWidget.bytes);
  }

  @override
  void dispose() {
    _evict(widget.bytes);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bytes = widget.bytes;
    if (widget.loading || bytes == null) {
      return Skeletonizer(
        child: Skeleton.leaf(
          child: AspectRatio(
            aspectRatio: shareCardWidth / shareCardPlaceholderHeight,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: widget.paper.colors.background,
                borderRadius: _radius,
              ),
            ),
          ),
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: _radius,
        boxShadow: context.cardShadow(),
      ),
      child: ClipRRect(
        borderRadius: _radius,
        child: Stack(
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final cacheWidth =
                    (constraints.maxWidth *
                            MediaQuery.devicePixelRatioOf(context))
                        .round();
                _cacheWidth = cacheWidth;
                return Image.memory(
                  bytes,
                  key: const ValueKey('share-preview-image'),
                  gaplessPlayback: true,
                  width: double.infinity,
                  fit: BoxFit.fitWidth,
                  cacheWidth: cacheWidth,
                  semanticLabel: widget.semanticLabel,
                );
              },
            ),
            if (widget.progress)
              const PositionedDirectional(
                top: 0,
                start: 0,
                end: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}
