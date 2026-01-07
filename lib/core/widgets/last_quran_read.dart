import 'package:flutter/material.dart';
import 'package:gap/gap.dart';

import '../../config/theme/color_scheme.dart';
import '../../config/theme/typography_styles.dart';
import '../../features/surah/presentation/pages/surah_list/widgets/custom_pressed_button.dart';
import '../constants/assets_dir.dart';
import '../helper functions/locale_helpers.dart';

class LastQuranRead extends StatelessWidget {
  const LastQuranRead({super.key});

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: 2.9,
      child: Container(
        padding: .only(
          left: context.isArabic ? 6 : 12,
          right: !context.isArabic ? 6 : 12,
          top: 8,
          bottom: 8,
        ),
        decoration: BoxDecoration(
          color: context.colorScheme.surfaceContainer,
          borderRadius: .all(Radius.circular(16)),
        ),
        child: Row(
          mainAxisAlignment: .spaceBetween,
          children: [
            Column(
              crossAxisAlignment: .start,
              textDirection: context.isArabic ? .rtl : .ltr,
              children: [
                Text(
                  "مُتَابَعَةُ التِّلَاوَةِ",
                  style: TS.bold20,
                  overflow: .ellipsis,
                ),
                Gap(2),
                Text(
                  "سُورَةُ الْأَنْعَام، الآية 12",
                  style: TS.bold16.copyWith(
                    color: context.colorScheme.onSurfaceVariant,
                  ),
                  overflow: .ellipsis,
                ),
                Gap(12),
                CustomPressedButton(),
              ],
            ),
            Image.asset(
              AssetsDir.iconsDir('quran_icon.png'),
              color: context.colorScheme.onSurface,
            ),
          ],
        ),
      ),
    );
  }
}
