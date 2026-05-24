import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import '../../../../../../config/theme/color_scheme.dart';

class SurahListPageAppBar extends StatelessWidget {
  const SurahListPageAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Row(
        textDirection: context.isArabic ? TextDirection.ltr : TextDirection.rtl,
        children: [
          IconButton(
            onPressed: () => context.push(AppRouter.settingsPath),
            icon: HugeIcon(
              icon: context.isArabic
                  ? HugeIcons.strokeRoundedArrowLeft02
                  : HugeIcons.strokeRoundedArrowRight02,
              size: 32,
              strokeWidth: 1,
              color: context.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
