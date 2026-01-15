import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/core/widgets/circular_bullet.dart';

import '../../../../../../config/theme/color_scheme.dart';
import '../../../../../../config/theme/typography_styles.dart';
import '../../../../../../core/helper functions/locale_helpers.dart';
import '../../../../../../core/widgets/prettier_tap.dart';
import '../../../../domain/entities/surah_entity.dart';
import 'surah_number_star.dart';

class SurahListTile extends StatelessWidget {
  final SurahEntity surah;

  const SurahListTile({super.key, required this.surah});
  String ayahLabel(int count) {
    if (count > 10) {
      return "آية";
    } else {
      return "آيات";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16.0),
      child: PrettierTap(
        onTap: () {
          GoRouter.of(
            context,
          ).push(AppRouter.mushafPath, extra: surah.pageNumber);
        },
        child: AspectRatio(
          aspectRatio: 4.8,

          child: Container(
            padding: .all(8),
            decoration: BoxDecoration(
              color: context.colorScheme.surfaceContainer,
              borderRadius: .all(Radius.circular(12)),
            ),
            child: Row(
              mainAxisAlignment: .spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: .start,
                  textDirection: context.isArabic ? .rtl : .ltr,
                  children: [
                    Text(surah.name, style: TS.bold20),
                    Row(
                      spacing: 6,
                      children: [
                        Text(
                          "${surah.revelationType} ",
                          style: TS.regular15.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        CircularBullet(),
                        Text(
                          "${surah.numberOfAyahs} ${ayahLabel(surah.numberOfAyahs)}",
                          style: TS.regular15.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                        CircularBullet(),

                        Text(
                          "صفحة ${surah.pageNumber}",
                          style: TS.regular15.copyWith(
                            color: context.colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                SurahNumberStar(surahNumber: surah.number),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
