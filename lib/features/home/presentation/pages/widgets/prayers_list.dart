import 'package:flutter/widgets.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/constants/prayers_list_constants.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/single_prayer_card.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class PrayersList extends StatelessWidget {
  const PrayersList({super.key, required this.prayerTimes});
  final PrayerTimes prayerTimes;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: BlocBuilder<PrayerCountdownCubit, PrayerCountdownState>(
        builder: (context, state) {
          return Row(
            spacing: 8,
            children: prayersList.map((prayerName) {
              return SinglePrayerCard(
                iconDir: prayersMap[prayerName]!.prayerIcon,
                prayerName: prayersMap[prayerName]!.prayerName,
                time24: prayerTimes.timings[prayerName]!,
                is24: sl<SettingsCubit>().state.settingsModel.isFormat12Hours,

                isCurrent: state is PrayerCountdownTick
                    ? state.prayerCountdown.currentPrayer == prayerName
                    : false,
              );
            }).toList(),
          );
        },
      ).animate().fadeIn(),
    );
  }
}
