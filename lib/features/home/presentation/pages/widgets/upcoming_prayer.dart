import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/core/helper%20functions/duration_helpers.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/helper%20functions/time_helpers.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class UpcomingPrayer extends StatelessWidget {
  const UpcomingPrayer({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PrayerCountdownCubit, PrayerCountdownState>(
      builder: (context, state) {
        if (state is PrayerCountdownTick) {
          final prayerCountdown = state.prayerCountdown.remainingTime
              .toDigitalClock()
              .toLocalized(context);
          final upcomingPrayer =
              prayersMap[state.prayerCountdown.nextPrayer]!.prayerName;

          return Column(
            children: [
              Gap(24),
              Text(
                DateTime.now().toReadableTime(context),
                style: TS.extra36.cairo,
              ),
              Text(
                S.current.remainingTimeLabel(prayerCountdown, upcomingPrayer),
                style: TS.medium16
                    .copyWith(color: context.colorScheme.onSurfaceVariant)
                    .cairo,
              ),
              Padding(
                padding: .symmetric(horizontal: 48, vertical: 16),
                child: Divider(color: context.colorScheme.primary),
              ),
            ],
          );
        }

        return SizedBox();
      },
    );
  }
}
