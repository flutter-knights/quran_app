import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/helper%20functions/duration_helpers.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/helper%20functions/time_helpers.dart';
import 'package:quran_app/core/widgets/toggle_widget.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class UpcomingPrayer extends StatelessWidget {
  const UpcomingPrayer({super.key});

  /// 12h time with the AM/PM marker (ص/م) rendered smaller than the time.
  Widget _heroTime12(
    BuildContext context,
    TextStyle timeStyle,
    TextStyle periodStyle,
  ) {
    final full = DateTime.now().format12h(context).toLocalized(context);
    final idx = full.lastIndexOf(' ');
    final timePart = idx > 0 ? full.substring(0, idx) : full;
    final period = idx > 0 ? full.substring(idx + 1) : '';
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(text: timePart, style: timeStyle),
          if (period.isNotEmpty)
            TextSpan(text: ' $period', style: periodStyle),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return BlocBuilder<PrayerCountdownCubit, PrayerCountdownState>(
      builder: (context, state) {
        if (state is! PrayerCountdownTick) return const SizedBox();

        final remaining =
            state.prayerCountdown.remainingTime.toDigitalClock().toLocalized(
                  context,
                );
        final nextPrayer = state.prayerCountdown.nextPrayer;
        // On Friday, Dhuhr is announced as Jumu'ah (matches the prayers row).
        final isFriday = DateTime.now().weekday == DateTime.friday;
        final upcomingPrayer = (isFriday && nextPrayer == PrayerName.dhuhr)
            ? S.of(context).jumuah
            : prayersMap[nextPrayer]!.prayerName;
        final heroStyle = TS.extra36.cairo.copyWith(
          fontSize: 46,
          fontWeight: FontWeight.w800,
          letterSpacing: -1.5,
          height: 1,
          color: scheme.onSurface,
        );
        // AM/PM (ص/م) sits well below the time's scale.
        final periodStyle = heroStyle.copyWith(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          letterSpacing: 0,
        );

        return Column(
          children: [
            const SizedBox(height: 12),
            ToggleWidget(
              defaultChild: _heroTime12(context, heroStyle, periodStyle),
              targetChild: Text(
                DateTime.now().to24hTime().toLocalized(context),
                style: heroStyle,
              ),
              value: sl<SettingsCubit>().state.settingsModel.isFormat12Hours,
            ),
            const SizedBox(height: 7),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 5,
                  height: 5,
                  decoration: BoxDecoration(
                    color: scheme.secondary,
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 6),
                Text(
                  S.of(context).remainingTimeLabel(remaining, upcomingPrayer),
                  style: TS.medium14
                      .copyWith(color: scheme.onSurfaceVariant)
                      .cairo,
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
