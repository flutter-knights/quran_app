import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';

import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/generated/l10n.dart';

class AhadithListItem extends StatelessWidget {
  final Hadith hadith;
  const AhadithListItem({super.key, required this.hadith});

  @override
  Widget build(BuildContext context) {
    return PrettierTap(
      onTap: () {},
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: context.colorScheme.surfaceContainer,
        ),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            spacing: 8,
            crossAxisAlignment: .stretch,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                crossAxisAlignment: .center,
                spacing: 8,
                children: [
                  hadithStatusWidget(context, hadith.status),
                  Text(
                    '${S.current.hadith_number_label}: ${hadith.hadithNumber.toLocalized(context)}',
                    style: TS.bold12.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
              Text(
                hadith.arabicHadith,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TS.bold16,
              ),
              Text(
                hadith.chapter!.chapterArabic,
                overflow: TextOverflow.ellipsis,
                maxLines: 2,
                style: TS.bold14.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

Widget hadithStatusWidget(BuildContext context, HadithStatus status) {
  return PrettierTap(
    child: Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        color: context.colorScheme.primary,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
        child: getHadithStatusText(status),
      ),
    ),
  );
}

Text getHadithStatusText(HadithStatus status) {
  switch (status) {
    case HadithStatus.daeef:
      return Text(S.current.status_daeef);

    case HadithStatus.hasan:
      return Text(S.current.status_hasan);
    case HadithStatus.sahih:
      return Text(S.current.status_sahih);
  }
}
