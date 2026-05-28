import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/icon_chip.dart';
import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';
import 'package:quran_app/generated/l10n.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({super.key, required this.dailyPrayerContext});
  final DailyPrayerContext dailyPrayerContext;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final date = dailyPrayerContext.prayerTimes.date;
    final place = [
      dailyPrayerContext.location.city,
      dailyPrayerContext.location.country,
    ].where((s) => s != null && s.isNotEmpty).join(', ');

    return Container(
      height: 60,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border(
          bottom: BorderSide(color: scheme.onSurface.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.current.hijriDateWithDay(
                    date.weekDay,
                    date.day.toLocalized(context),
                    date.month,
                    date.year.toLocalized(context),
                  ),
                  style: TS.bold14.cairo,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    HugeIcon(
                      icon: HugeIcons.strokeRoundedLocation01,
                      color: scheme.onSurfaceVariant,
                      size: 11,
                    ),
                    const SizedBox(width: 4),
                    Flexible(
                      child: Text(
                        place,
                        style: TS.medium14
                            .copyWith(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            )
                            .cairo,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          IconChip(
            icon: const HugeIcon(
              icon: HugeIcons.strokeRoundedSettings01,
              color: Colors.white,
              size: 16,
            ),
            onPressed: () => context.push(AppRouter.settingsPath),
          ),
        ],
      ),
    );
  }
}
