import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/ornament_divider.dart';
import 'package:quran_app/core/widgets/design/home_skeleton.dart';
import 'package:quran_app/features/home/presentation/cubit/daily_prayer_context_cubit.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/home_app_bar.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/last_read_card.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/location_recovery_card.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/daily_hadith_card.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/prayers_list.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/quick_access_grid.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/upcoming_prayer.dart';
import 'package:quran_app/generated/l10n.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: BlocListener<DailyPrayerContextCubit, DailyPrayerContextState>(
          listener: (context, state) {
            if (state is DailyPrayerContextLoaded) {
              context.read<PrayerCountdownCubit>().startTimer(
                    state.dailyPrayerContext,
                  );
            }
          },
          child: BlocBuilder<DailyPrayerContextCubit, DailyPrayerContextState>(
            builder: (context, state) {
              if (state is DailyPrayerContextLoading) {
                return const HomeSkeleton();
              }
              if (state is DailyPrayerContextFailed) {
                final failure = state.failure;
                if (failure is LocationPermissionDeniedFailure) {
                  return LocationRecoveryCard(
                    actionLabel: S.of(context).home_locationCard_enable,
                    onAction: () async {
                      await Geolocator.requestPermission();
                      if (context.mounted) {
                        context
                            .read<DailyPrayerContextCubit>()
                            .fetchDailyPrayerContext();
                      }
                    },
                  );
                }
                if (failure is LocationPermissionDeniedForeverFailure) {
                  return LocationRecoveryCard(
                    actionLabel: S.of(context).home_locationCard_openSettings,
                    onAction: () => Geolocator.openAppSettings(),
                  );
                }
                if (failure is LocationServiceDisabledFailure) {
                  return LocationRecoveryCard(
                    actionLabel: S.of(context).home_locationCard_openSettings,
                    onAction: () => Geolocator.openLocationSettings(),
                  );
                }
                return Center(child: Text(state.message));
              }
              if (state is DailyPrayerContextLoaded) {
                final ctx = state.dailyPrayerContext;
                final last = LastReadCard.maybeBuild(context);
                return Column(
                  children: [
                    HomeAppBar(dailyPrayerContext: ctx),
                    Expanded(
                      child: SingleChildScrollView(
                        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const UpcomingPrayer(),
                            const SizedBox(height: 14),
                            const OrnamentDivider(),
                            const SizedBox(height: 14),
                            AppSectionHeader(label: S.of(context).prayers),
                            const SizedBox(height: 10),
                            PrayersList(prayerTimes: ctx.prayerTimes),
                            if (last != null) ...[
                              const SizedBox(height: 14),
                              AppSectionHeader(label: S.of(context).lastRead),
                              const SizedBox(height: 10),
                              last,
                            ],
                            const SizedBox(height: 14),
                            AppSectionHeader(label: S.of(context).quickAccess),
                            const SizedBox(height: 10),
                            const QuickAccessGrid(),
                            const DailyHadithCard(),
                            const SizedBox(height: 28),
                            Center(
                              child: Text(
                                'بِسْمِ اللَّهِ الرَّحْمَٰنِ الرَّحِيمِ',
                                textDirection: TextDirection.rtl,
                                textAlign: TextAlign.center,
                                style: TS.bold16.scheherazade.copyWith(
                                  fontSize: 11,
                                  color: scheme.onSurface.withValues(alpha: 0.4),
                                  height: 1.9,
                                ),
                              ),
                            ),
                            const SizedBox(height: 4),
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              return const SizedBox();
            },
          ),
        ),
      ),
    );
  }
}
