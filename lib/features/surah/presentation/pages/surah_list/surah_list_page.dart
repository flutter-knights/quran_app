import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/settings_bottom_sheet.dart';

import '../../../../../core/constants/assets_dir.dart';

class SurahListPage extends StatelessWidget {
  const SurahListPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            spacing: 16,
            crossAxisAlignment: .stretch,
            children: [SurahListAppBar(), SurahListSelection()],
          ),
        ),
      ),
    );
  }
}

class SurahListAppBar extends StatelessWidget {
  const SurahListAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return Row(
      textDirection: context.isArabic ? .ltr : .rtl,
      children: [
        IconButton(
          onPressed: () {
            // GoRouter.of(context).pop();
            showSettings(context);
          },
          icon: HugeIcon(
            icon: context.isArabic
                ? HugeIcons.strokeRoundedArrowLeft02
                : HugeIcons.strokeRoundedArrowRight02,
            size: 32,
            strokeWidth: 1.3,
          ),
        ),
      ],
    );
  }
}

class SurahListSelection extends StatelessWidget {
  const SurahListSelection({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        AspectRatio(
          aspectRatio: 3,
          child: Container(
            padding: .only(
              left: context.isArabic ? 6 : 12,
              right: !context.isArabic ? 6 : 12,
              top: 8,
              bottom: 8,
            ),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainerHigh,
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
                      style: TS.semi16,
                      overflow: .ellipsis,
                    ),
                    Gap(12),
                    CustomPressedButton(),
                  ],
                ),
                Image.asset(AssetsDir.iconsDir('quran_icon.png')),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class CustomPressedButton extends StatelessWidget {
  const CustomPressedButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: .symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainerLow,
        borderRadius: .all(Radius.circular(8)),
      ),
      child: Text("تابع التلاوة", style: TS.semi12),
    );
  }
}
