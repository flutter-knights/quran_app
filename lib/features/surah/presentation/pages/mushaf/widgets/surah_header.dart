import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';

import 'package:quran_app/config/theme/typography_styles.dart';
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
      padding: const EdgeInsets.symmetric(horizontal: 8.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.asset(
            "assets/images/surah_header.svg",
            width: width,

            fit: BoxFit.fill,
            colorFilter: ColorFilter.mode(
              context.colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),

          Directionality(
            textDirection: TextDirection.rtl,

            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Gap(12),
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

          Positioned(
            left: width * 0.18,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("رقمها", style: TS.regular9),
                Text(
                  surahNumber.toString(),
                  style: TS.regular10.copyWith(height: 1),
                ),
              ],
            ),
          ),

          Positioned(
            right: width * 0.18,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("آياتها", style: TS.regular9),
                Text(
                  verseCount.toString(),
                  style: TS.regular10.copyWith(height: 1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
