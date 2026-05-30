import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/helper%20functions/time_helpers.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/single_prayer_card.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class PrayersList extends StatelessWidget {
  const PrayersList({super.key, required this.prayerTimes});
  final PrayerTimes prayerTimes;

  @override
  Widget build(BuildContext context) {
    // On Friday, Dhuhr is replaced by Jumu'ah (matches the prayer strip).
    // Derive the weekday from the context date these timings belong to — not
    // DateTime.now() — so the label stays correct after the post-Isha roll.
    final isFriday =
        prayerTimes.date.gregorianDate.gregorianDate().weekday ==
            DateTime.friday;
    return BlocBuilder<PrayerCountdownCubit, PrayerCountdownState>(
      builder: (context, state) {
        return Row(
          spacing: 6,
          children: prayersList.map((prayerName) {
            final label = (isFriday && prayerName == PrayerName.dhuhr)
                ? S.of(context).jumuah
                : prayersMap[prayerName]!.prayerName;
            return SinglePrayerCard(
              iconDir: prayersMap[prayerName]!.prayerIcon,
              prayerName: label,
              time24: prayerTimes.timings[prayerName]!,
              is24: sl<SettingsCubit>().state.settingsModel.isFormat12Hours,
              isNext: state is PrayerCountdownTick
                  ? state.prayerCountdown.nextPrayer == prayerName
                  : false,
            );
          }).toList(),
        );
      },
    );
  }
}
