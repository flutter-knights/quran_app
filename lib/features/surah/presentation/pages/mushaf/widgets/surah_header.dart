import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import 'package:quran_app/core/constants/device_size_info.dart';

import '../../../../../../config/theme/color_scheme.dart';

const AssetImage kSurahHeaderImage = AssetImage('assets/images/header.png');

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
    final width = context.width;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6.0),
      child: Stack(
        alignment: Alignment.center,
        children: [
          Image(
            image: ResizeImage(kSurahHeaderImage, width: width.toInt()),
            color: context.colorScheme.onSurface,
            colorBlendMode: BlendMode.srcIn,
            fit: BoxFit.fill,
            gaplessPlayback: true,
          ),
          Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                const Gap(6),
                Text(
                  name,
                  locale: const Locale('ar'),
                  style: TextStyle(
                    fontFamily: 'QCF_P000',
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
