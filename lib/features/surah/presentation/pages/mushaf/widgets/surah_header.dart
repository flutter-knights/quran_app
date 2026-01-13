import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:quran_app/core/constants/device_size_info.dart';

import '../../../../../../config/theme/color_scheme.dart';

class SurahHeader extends StatelessWidget {
  const SurahHeader({
    super.key,
    required this.name,
    required this.verseCount,
    required this.surahNumber,
    required this.fontSize,
    required this.lineHeight,
  });

  final String name;
  final int verseCount;
  final int surahNumber;
  final double fontSize;
  final double lineHeight;

  @override
  Widget build(BuildContext context) {
    final double width = context.width;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image.asset(
            "assets/images/header.png",
            width: width,
            color: context.colorScheme.onSurface,
            fit: BoxFit.fill,
          ),

          Directionality(
            textDirection: TextDirection.rtl,

            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Gap(6),
                Text(
                  name,
                  locale: const Locale('ar'),
                  style: TextStyle(
                    fontFamily: "QCF_P000",
                    fontSize: fontSize * 1.4,
                    color: context.colorScheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
