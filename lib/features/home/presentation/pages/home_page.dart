import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/domain/usecases/pre_cache_prayer_times.dart';
import 'package:quran_app/features/notifications/domain/usecases/sync_daily_adhans.dart';
import 'package:quran_app/features/home/presentation/cubit/daily_prayer_context_cubit.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/home_view.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (_) =>
              sl<DailyPrayerContextCubit>()..fetchDailyPrayerContext(),
        ),
        BlocProvider(create: (_) => PrayerCountdownCubit()),
      ],
      child: MultiBlocListener(
        listeners: [
          // Forward the silent flag from countdown cubit to context cubit.
          BlocListener<PrayerCountdownCubit, PrayerCountdownState>(
            listenWhen: (_, s) => s is PrayerCountdownRequestRefresh,
            listener: (context, state) {
              final s = state as PrayerCountdownRequestRefresh;
              context
                  .read<DailyPrayerContextCubit>()
                  .fetchDailyPrayerContext(silent: s.silent);
            },
          ),
          // Fire-and-forget pre-cache on every successful context load.
          BlocListener<DailyPrayerContextCubit, DailyPrayerContextState>(
            listenWhen: (_, s) => s is DailyPrayerContextLoaded,
            listener: (context, state) {
              final loaded = state as DailyPrayerContextLoaded;
              unawaited(
                sl<PreCachePrayerTimes>().call(
                  PreCachePrayerTimesParams(
                    location: loaded.dailyPrayerContext.location,
                  ),
                ),
              );
            },
          ),
          BlocListener<DailyPrayerContextCubit, DailyPrayerContextState>(
            listenWhen: (_, s) => s is DailyPrayerContextLoaded,
            listener: (context, state) {
              final loaded = state as DailyPrayerContextLoaded;
              unawaited(
                sl<SyncDailyAdhans>().call(
                  SyncDailyAdhansParams(
                    prayerTimes: loaded.dailyPrayerContext.prayerTimes,
                  ),
                ),
              );
            },
          ),
        ],
        child: HomeView(),
      ),
    );
  }
}
