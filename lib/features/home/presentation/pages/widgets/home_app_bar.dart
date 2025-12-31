import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/home/domain/entities/daily_prayer_context.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/settings_bottom_sheet.dart';
import 'package:quran_app/generated/l10n.dart';

class HomeAppBar extends StatelessWidget {
  const HomeAppBar({super.key, required this.dailyPrayerContext});
  final DailyPrayerContext dailyPrayerContext;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
      child: Row(
        crossAxisAlignment: .start,
        mainAxisAlignment: .spaceBetween,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: .start,
              children: [
                Text(
                  S.current.hijriDateWithDay(
                    dailyPrayerContext.prayerTimes.date.weekDay,
                    dailyPrayerContext.prayerTimes.date.day.toLocalized(
                      context,
                    ),
                    dailyPrayerContext.prayerTimes.date.month,
                    dailyPrayerContext.prayerTimes.date.year.toLocalized(
                      context,
                    ),
                  ),
                  style: TS.extra20.cairo,
                ),

                Text(
                  '${dailyPrayerContext.location.city!}, ${dailyPrayerContext.location.country!}',
                  style: TS.medium14
                      .copyWith(color: context.colorScheme.onSurfaceVariant)
                      .cairo,
                ),
              ],
            ),
          ),
          PrettierTap(
            onTap: () => showSettings(context),
            child: HugeIcon(icon: HugeIcons.strokeRoundedSettings01, size: 28),
          ),
        ],
      ),
    );
  }
}
