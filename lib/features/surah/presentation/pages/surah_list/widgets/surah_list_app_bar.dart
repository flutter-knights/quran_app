import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/settings_bottom_sheet.dart';

import '../../../../../../config/theme/color_scheme.dart';

class SurahListPageAppBar extends StatelessWidget {
  const SurahListPageAppBar({super.key});

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Row(
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
              strokeWidth: 1,
              color: context.colorScheme.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}
