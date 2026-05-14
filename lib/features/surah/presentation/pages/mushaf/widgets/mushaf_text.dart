import 'package:flutter/material.dart';

import '../../../../../../core/di/dependency_injection.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../cubit/mushaf/mushaf_state.dart';
import '../../../utils/current_ayah_notifier.dart';
import 'ayah_text_span_builder.dart';

class MushafText extends StatelessWidget {
  const MushafText({super.key, required this.loaded, required this.pageNumber});

  final MushafLoaded loaded;
  final int pageNumber;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<AyahIdentifier?>(
      valueListenable: sl<CurrentAyahNotifier>(),
      builder: (context, currentAyah, _) {
        final spans = AyahTextSpanBuilder.buildHighlightOverlay(
          baseSpans: loaded.spans,
          page: loaded.page,
          currentAyah: currentAyah,
          highlightedStyle: loaded.highlightedStyle,
          normalStyle: loaded.normalStyle,
        );
        return SizedBox(
          width: loaded.pageWidth,
          child: RichText(
            textDirection: TextDirection.rtl,
            textAlign: TextAlign.center,
            maxLines: 15,
            overflow: TextOverflow.clip,
            text: TextSpan(children: spans),
          ),
        );
      },
    );
  }
}
