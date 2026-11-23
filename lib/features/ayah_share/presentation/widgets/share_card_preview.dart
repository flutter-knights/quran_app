import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../../config/theme/color_scheme.dart';
import '../../../../core/constants/mushaf_paper.dart';
import '../../../surah/presentation/utils/mushaf_paper_colors.dart';

class ShareCardPreview extends StatelessWidget {
  const ShareCardPreview({
    super.key,
    required this.bytes,
    required this.paper,
    required this.progress,
    required this.semanticLabel,
  });

  final Uint8List? bytes;
  final MushafPaper paper;
  final bool progress;
  final String semanticLabel;

  static final _radius = BorderRadius.circular(12);

  @override
  Widget build(BuildContext context) {
    final bytes = this.bytes;
    if (bytes == null) {
      return Skeletonizer(
        child: Skeleton.leaf(
          child: AspectRatio(
            aspectRatio: 1080 / 888,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: paper.colors.background,
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
            Image.memory(
              bytes,
              key: const ValueKey('share-preview-image'),
              gaplessPlayback: true,
              width: double.infinity,
              fit: BoxFit.fitWidth,
              semanticLabel: semanticLabel,
            ),
            if (progress)
              const Positioned(
                top: 0,
                left: 0,
                right: 0,
                child: LinearProgressIndicator(minHeight: 2),
              ),
          ],
        ),
      ),
    );
  }
}
