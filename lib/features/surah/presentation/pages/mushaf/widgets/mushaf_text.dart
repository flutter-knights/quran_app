import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_state.dart';
import '../../../../domain/entities/mushaf_page_entity.dart';

import 'ayah_text_span_builder.dart';

class MushafText extends StatelessWidget {
  final MushafPageEntity page;
  final int pageNumber;
  final double pageWidth;
  final double fontSize;
  final double lineHeight;

  const MushafText({
    super.key,
    required this.page,
    required this.pageNumber,
    required this.pageWidth,
    required this.fontSize,
    required this.lineHeight,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackCubit, PlaybackState>(
      buildWhen: (p, c) => p.currentAyah != c.currentAyah,
      builder: (context, state) {
        final spans = AyahTextSpanBuilder.build(
          context: context,
          page: page,
          pageNumber: pageNumber,
          fontSize: fontSize,
          lineHeight: lineHeight,
          pageWidth: pageWidth,
          currentAyah: state.currentAyah,
        );

        return SizedBox(
          width: pageWidth,
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
