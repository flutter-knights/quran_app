import 'package:flutter/material.dart';

import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';

import 'mushaf_text.dart';

class MushafLayout extends StatelessWidget {
  final int pageNumber;
  final MushafPageEntity page;

  const MushafLayout({super.key, required this.pageNumber, required this.page});

  static const int totalLines = 15;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: 1 / 1.93,
            child: LayoutBuilder(
              builder: (context, constraints) {
                final pageWidth = constraints.maxWidth;
                final fontSize = pageWidth / totalLines * 0.9;
                final lineHeight = pageWidth / totalLines * 1.9;

                return MushafText(
                  page: page,
                  pageNumber: pageNumber,
                  pageWidth: pageWidth,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(pageNumber.toString()),
      ],
    );
  }
}
