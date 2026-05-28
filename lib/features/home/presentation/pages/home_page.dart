import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
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
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';

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
        BlocProvider(create: (_) => sl<LastReadCubit>()),
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
              final settings = context.read<SettingsCubit>().state.settingsModel;
              final locale = settings.isArabic ? 'ar' : 'en';
              unawaited(
                sl<SyncDailyAdhans>().call(
                  SyncDailyAdhansParams(
                    prayerTimes: loaded.dailyPrayerContext.prayerTimes,
                    enabledByPrayer: settings.adhanEnabledByPrayer,
                    reminderMinutesByPrayer: settings.reminderMinutesByPrayer,
                    localeCode: locale,
                  ),
                ),
              );
              _enableOrRefreshStrip(context, loaded);
            },
          ),
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (prev, curr) {
              final p = prev.settingsModel;
              final c = curr.settingsModel;
              return p.isPrayerStripPinned != c.isPrayerStripPinned ||
                  p.isArabic != c.isArabic ||
                  p.palette != c.palette ||
                  p.isFormat12Hours != c.isFormat12Hours ||
                  !_mapBoolEq(p.adhanEnabledByPrayer, c.adhanEnabledByPrayer) ||
                  !_mapIntEq(
                    p.reminderMinutesByPrayer, c.reminderMinutesByPrayer,
                  );
            },
            listener: (context, settings) {
              final ctxState = context.read<DailyPrayerContextCubit>().state;
              if (settings.settingsModel.isPrayerStripPinned &&
                  ctxState is DailyPrayerContextLoaded) {
                _enableOrRefreshStrip(context, ctxState);
              } else if (!settings.settingsModel.isPrayerStripPinned) {
                unawaited(sl<DisablePrayerStrip>().call(NoParams()));
              }

              // Re-sync adhans + reminders whenever the relevant settings change.
              if (ctxState is DailyPrayerContextLoaded) {
                final locale = settings.settingsModel.isArabic ? 'ar' : 'en';
                unawaited(
                  sl<SyncDailyAdhans>().call(
                    SyncDailyAdhansParams(
                      prayerTimes: ctxState.dailyPrayerContext.prayerTimes,
                      enabledByPrayer:
                          settings.settingsModel.adhanEnabledByPrayer,
                      reminderMinutesByPrayer:
                          settings.settingsModel.reminderMinutesByPrayer,
                      localeCode: locale,
                    ),
                  ),
                );
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
      // `isFormat12Hours` is named opposite to its meaning — `true` means
      // the user enabled the "24-hour format" toggle in settings.
      use24Hour: settings.isFormat12Hours,
      // Drive the next-prayer pill from the live palette accent so the
      // notification tracks the in-app theme (single source of truth).
      accentColor: settings.palette.primary.toARGB32(),
    );
    unawaited(
      sl<EnablePrayerStrip>().call(
        EnablePrayerStripParams(state: stripState),
      ),
    );
  }

  static bool _mapBoolEq(Map<PrayerName, bool> a, Map<PrayerName, bool> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }

  static bool _mapIntEq(Map<PrayerName, int> a, Map<PrayerName, int> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
