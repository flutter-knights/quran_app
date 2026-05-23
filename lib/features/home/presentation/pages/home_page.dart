import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/usecases/pre_cache_prayer_times.dart';
import 'package:quran_app/features/home/presentation/cubit/daily_prayer_context_cubit.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/home_view.dart';
import 'package:quran_app/features/notifications/domain/builders/prayer_strip_state_builder.dart';
import 'package:quran_app/features/notifications/domain/services/next_prayer_resolver.dart';
import 'package:quran_app/features/notifications/domain/usecases/disable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/enable_prayer_strip.dart';
import 'package:quran_app/features/notifications/domain/usecases/sync_daily_adhans.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

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
          BlocListener<PrayerCountdownCubit, PrayerCountdownState>(
            listenWhen: (_, s) => s is PrayerCountdownRequestRefresh,
            listener: (context, state) {
              final s = state as PrayerCountdownRequestRefresh;
              context
                  .read<DailyPrayerContextCubit>()
                  .fetchDailyPrayerContext(silent: s.silent);
            },
          ),
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
              final locale = context.read<SettingsCubit>().state.settingsModel.isArabic ? 'ar' : 'en';
              unawaited(
                sl<SyncDailyAdhans>().call(
                  SyncDailyAdhansParams(
                    prayerTimes: loaded.dailyPrayerContext.prayerTimes,
                    localeCode: locale,
                  ),
                ),
              );
              _enableOrRefreshStrip(context, loaded);
            },
          ),
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (prev, curr) =>
                prev.settingsModel.isPrayerStripPinned !=
                    curr.settingsModel.isPrayerStripPinned ||
                prev.settingsModel.isArabic != curr.settingsModel.isArabic,
            listener: (context, settings) {
              final ctxState = context.read<DailyPrayerContextCubit>().state;
              if (settings.settingsModel.isPrayerStripPinned &&
                  ctxState is DailyPrayerContextLoaded) {
                _enableOrRefreshStrip(context, ctxState);
              } else if (!settings.settingsModel.isPrayerStripPinned) {
                unawaited(sl<DisablePrayerStrip>().call(NoParams()));
              }
            },
          ),
        ],
        child: HomeView(),
      ),
    );
  }

  void _enableOrRefreshStrip(
    BuildContext context,
    DailyPrayerContextLoaded loaded,
  ) {
    final settings = context.read<SettingsCubit>().state.settingsModel;
    if (!settings.isPrayerStripPinned) return;

    final now = DateTime.now();
    final nextPrayer = NextPrayerResolver.resolve(
      timings: loaded.dailyPrayerContext.prayerTimes.timings,
      now: now,
    );
    final stripState = PrayerStripStateBuilder.build(
      prayerTimes: loaded.dailyPrayerContext.prayerTimes,
      nextPrayer: nextPrayer,
      localeCode: settings.isArabic ? 'ar' : 'en',
      isFriday: now.weekday == DateTime.friday,
    );
    unawaited(
      sl<EnablePrayerStrip>().call(
        EnablePrayerStripParams(state: stripState),
      ),
    );
  }
}
