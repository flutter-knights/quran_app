import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/helper%20functions/duration_helpers.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/helper%20functions/time_helpers.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
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
                    DateTime.now().to24hTime(),
                    style: TS.extra36.cairo,
                  )
                  .animate(
                    target:
                        sl<SettingsCubit>().state.settingsModel.isFormat12Hours
                        ? 0
                        : 1,
                  )
                  .fadeOut(duration: 300.ms)
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(0.9, 0.9),
                    duration: 300.ms,
                  ) // Shrink slightly
                  .swap(
                    duration: 300.ms,
                    builder: (_, __) =>
                        Text(
                              DateTime.now()
                                  .format12h(context)
                                  .toLocalized(context),
                              style: TS.extra36.cairo,
                            )
                            .animate()
                            .fadeIn(duration: 300.ms)
                            .scale(
                              begin: const Offset(0.9, 0.9),
                              end: const Offset(1, 1),
                            ),
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
