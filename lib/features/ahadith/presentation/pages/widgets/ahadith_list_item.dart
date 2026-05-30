import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_status_badge.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/generated/l10n.dart';

class AhadithListItem extends StatelessWidget {
  const AhadithListItem({super.key, required this.hadith, required this.bookSlug});
  final Hadith hadith;
  final String bookSlug;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 12,
      onTap: () => context.push(
        AppRouter.hadithPath,
        extra: (hadith: hadith, bookSlug: bookSlug),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              AppStatusBadge(
                color: statusColor(hadith.status),
                label: statusLabel(context, hadith.status),
              ),
              Text(
                '#${hadith.hadithNumber.toLocalized(context)}',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.secondary,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            hadith.arabicHadith,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TS.bold16.scheherazade.copyWith(
              fontSize: 15,
              color: scheme.onSurface,
              height: 1.7,
            ),
          ),
          if (hadith.chapter != null) ...[
            const SizedBox(height: 8),
            Text(
              hadith.chapter!.chapterArabic,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

Color statusColor(HadithStatus s) => switch (s) {
      HadithStatus.sahih => const Color(0xFF3D9E6E),
      HadithStatus.hasan => const Color(0xFFC8882A),
      HadithStatus.daeef => const Color(0xFFD05050),
    };

String statusLabel(BuildContext context, HadithStatus s) => switch (s) {
      HadithStatus.sahih => S.of(context).status_sahih,
      HadithStatus.hasan => S.of(context).status_hasan,
      HadithStatus.daeef => S.of(context).status_daeef,
    };
