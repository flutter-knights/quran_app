import 'package:flutter/material.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/circler_bullet.dart';

import '../../../../../../config/theme/color_scheme.dart';
import '../../../../../../config/theme/typography_styles.dart';
import '../../../../../../core/helper functions/locale_helpers.dart';
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
      child: AspectRatio(
        aspectRatio: 5.1,

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
                  Text(
                    surah.qcfSurahName,
                    style: TS.medium32.copyWith(
                      fontFamily: "QCF_P000",
                      height: 1.1,
                    ),
                    overflow: .ellipsis,
                  ),
                  Row(
                    spacing: 6,
                    children: [
                      Text(
                        "${surah.revelationType} ",
                        style: TS.regular15.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      CirclerBullet(),
                      Text(
                        "${surah.numberOfAyahs} ${ayahLabel(surah.numberOfAyahs)}",
                        style: TS.regular15.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      CirclerBullet(),

                      Text(
                        "صفحة${surah.pageNumber}",
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
    );
  }
}
