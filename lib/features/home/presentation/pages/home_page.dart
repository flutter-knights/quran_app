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
          // Advance the strip's highlighted pill as prayers pass through the
          // day. Without this the strip is only re-pushed on context load or a
          // settings change, so the pill goes stale — which looked like a
          // "12h format doesn't track the current prayer" bug (toggling the
          // format merely forced a refresh that happened to correct it).
          BlocListener<PrayerCountdownCubit, PrayerCountdownState>(
            listenWhen: (prev, curr) =>
                prev is PrayerCountdownTick &&
                curr is PrayerCountdownTick &&
                prev.prayerCountdown.nextPrayer !=
                    curr.prayerCountdown.nextPrayer,
            listener: (context, _) {
              final ctxState = context.read<DailyPrayerContextCubit>().state;
              if (ctxState is DailyPrayerContextLoaded) {
                _enableOrRefreshStrip(context, ctxState);
              }
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
              // Settings changes (theme/language/format) re-sync the prayer
              // strip + adhans. None of that notification/foreground-service
              // work should ever be able to crash the app on a setting change.
              try {
                final ctxState =
                    context.read<DailyPrayerContextCubit>().state;
                // Only refresh the strip while it's pinned; disabling is
                // handled by a dedicated listener on the pin transition, so we
                // don't spin up the service on every unrelated settings change.
                if (settings.settingsModel.isPrayerStripPinned &&
                    ctxState is DailyPrayerContextLoaded) {
                  _enableOrRefreshStrip(context, ctxState);
                }

                // Re-sync adhans + reminders when relevant settings change.
                if (ctxState is DailyPrayerContextLoaded) {
                  final locale =
                      settings.settingsModel.isArabic ? 'ar' : 'en';
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
              } catch (e, st) {
                debugPrint('settings-change strip/adhan sync failed: $e\n$st');
              }
            },
          ),
          // Disable the strip only when the user actually turns the pin OFF —
          // not on every theme/language/format change while it's already off.
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (prev, curr) =>
                prev.settingsModel.isPrayerStripPinned &&
                !curr.settingsModel.isPrayerStripPinned,
            listener: (context, _) {
              unawaited(sl<DisablePrayerStrip>().call(NoParams()));
            },
          ),
        ],
        // Re-assert the strip when the app returns to the foreground: the OS
        // can kill the hosting foreground service while we're backgrounded, and
        // a warm resume (no cold start) wouldn't otherwise re-fire the loaders.
        child: _StripResumeGuard(child: HomeView()),
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

/// (Re)builds and pushes the strip from the loaded prayer context, honouring
/// the user's pin toggle. Top-level so both the bloc listeners and the
/// lifecycle guard can share it.
void _enableOrRefreshStrip(
  BuildContext context,
  DailyPrayerContextLoaded loaded,
) {
  final settings = context.read<SettingsCubit>().state.settingsModel;
  if (!settings.isPrayerStripPinned) return;

  // Posting the prayer-strip notification can throw (notification/foreground-
  // service/exact-alarm failures). A failure here must never crash the app —
  // it's a best-effort side effect of (re)building the strip.
  try {
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
      sl<EnablePrayerStrip>()
          .call(EnablePrayerStripParams(state: stripState))
          .then(
            (r) => r.fold(
              (f) => debugPrint('[prayer-strip] enable failed: ${f.message}'),
              (_) {},
            ),
          ),
    );
  } catch (e, st) {
    debugPrint('refresh prayer strip failed: $e\n$st');
  }
}

/// Watches the app lifecycle and re-asserts the pinned strip on resume, so it
/// survives the hosting foreground service being reclaimed while backgrounded.
class _StripResumeGuard extends StatefulWidget {
  const _StripResumeGuard({required this.child});

  final Widget child;

  @override
  State<_StripResumeGuard> createState() => _StripResumeGuardState();
}

class _StripResumeGuardState extends State<_StripResumeGuard>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    // Re-fetch so a now-granted location clears the recovery card. Silent to
    // avoid a skeleton flash when data is already showing.
    context.read<DailyPrayerContextCubit>().fetchDailyPrayerContext(silent: true);
    final ctxState = context.read<DailyPrayerContextCubit>().state;
    if (ctxState is DailyPrayerContextLoaded) {
      _enableOrRefreshStrip(context, ctxState);
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
