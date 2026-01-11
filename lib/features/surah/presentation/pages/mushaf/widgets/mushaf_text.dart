import 'package:flutter/material.dart';

import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';

import 'ayah_text_span_builder.dart';

class MushafText extends StatelessWidget {
  final MushafPageEntity page;
  final int pageNumber;
  final double pageWidth;
  final double fontSize;
  final double lineHeight;
  final double letterSpacing;

  const MushafText({
    super.key,
    required this.page,
    required this.pageNumber,
    required this.pageWidth,
    required this.fontSize,
    required this.lineHeight,
    required this.letterSpacing,
  });

  @override
  Widget build(BuildContext context) {
    final spans = AyahTextSpanBuilder.build(
      context: context,
      page: page,
      pageNumber: pageNumber,
      fontSize: fontSize,
      lineHeight: lineHeight,
      pageWidth: pageWidth,
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
  }
}
