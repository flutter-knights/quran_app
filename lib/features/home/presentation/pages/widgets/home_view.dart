import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/features/home/presentation/cubit/daily_prayer_context_cubit.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/home_action_buttons.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/home_app_bar.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/prayers_list.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/upcoming_prayer.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: BlocListener<DailyPrayerContextCubit, DailyPrayerContextState>(
          listener: (context, state) {
            if (state is DailyPrayerContextLoaded) {
              context.read<PrayerCountdownCubit>().startTimer(
                state.dailyPrayerContext,
              );
            }
          },
          child: Column(
            children: [
              BlocBuilder<DailyPrayerContextCubit, DailyPrayerContextState>(
                builder: (context, state) {
                  if (state is DailyPrayerContextLoading) {
                    return const Expanded(
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (state is DailyPrayerContextFailed) {
                    return Expanded(child: Center(child: Text(state.error)));
                  }
                  if (state is DailyPrayerContextLoaded) {
                    return Column(
                      children: [
                        HomeAppBar(
                          dailyPrayerContext: state.dailyPrayerContext,
                        ),
                        UpcomingPrayer(),
                        PrayersList(
                          prayerTimes: state.dailyPrayerContext.prayerTimes,
                        ),
                      ],
                    );
                  }
                  return const SizedBox();
                },
              ),
              const HomeActionButtons(),
            ],
          ),
        ),
      ),
    );
  }
}
