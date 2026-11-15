import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/domain/usecases/pre_cache_prayer_times.dart';
import 'package:quran_app/features/home/presentation/cubit/daily_prayer_context_cubit.dart';
import 'package:quran_app/features/home/presentation/cubit/prayer_countdown_cubit.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/home_view.dart';
import 'package:quran_app/features/notifications/presentation/cubit/alerts_sync_cubit.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider(
          create: (context) {
            final s = context.read<SettingsCubit>().state.settingsModel;
            return sl<DailyPrayerContextCubit>()..fetchDailyPrayerContext(
              method: s.calculationMethod,
              school: s.asrSchool,
            );
          },
        ),
        BlocProvider(create: (_) => PrayerCountdownCubit()),
        BlocProvider(create: (_) => sl<AlertsSyncCubit>()),
      ],
      child: MultiBlocListener(
        listeners: [
          BlocListener<PrayerCountdownCubit, PrayerCountdownState>(
            listenWhen: (_, s) => s is PrayerCountdownRequestRefresh,
            listener: (context, state) {
              final s = state as PrayerCountdownRequestRefresh;
              final settings = context
                  .read<SettingsCubit>()
                  .state
                  .settingsModel;
              context.read<DailyPrayerContextCubit>().fetchDailyPrayerContext(
                silent: s.silent,
                method: settings.calculationMethod,
                school: settings.asrSchool,
              );
            },
          ),
          BlocListener<DailyPrayerContextCubit, DailyPrayerContextState>(
            listenWhen: (_, s) => s is DailyPrayerContextLoaded,
            listener: (context, state) {
              final loaded = state as DailyPrayerContextLoaded;
              final settings = context
                  .read<SettingsCubit>()
                  .state
                  .settingsModel;
              context.read<AlertsSyncCubit>().requestSync();
              unawaited(
                sl<PreCachePrayerTimes>()(
                  PreCachePrayerTimesParams(
                    location: loaded.dailyPrayerContext.location,
                    method: settings.calculationMethod,
                    school: settings.asrSchool,
                  ),
                ).then((_) {
                  if (context.mounted) {
                    context.read<AlertsSyncCubit>().requestSync();
                  }
                }),
              );
            },
          ),
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (prev, curr) => AlertsSyncCubit.listensTo(
              prev.settingsModel,
              curr.settingsModel,
            ),
            listener: (context, _) =>
                context.read<AlertsSyncCubit>().requestSync(),
          ),
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (prev, curr) =>
                prev.settingsModel.calculationMethod !=
                    curr.settingsModel.calculationMethod ||
                prev.settingsModel.asrSchool != curr.settingsModel.asrSchool,
            listener: (context, settings) {
              context.read<DailyPrayerContextCubit>().fetchDailyPrayerContext(
                silent: true,
                method: settings.settingsModel.calculationMethod,
                school: settings.settingsModel.asrSchool,
              );
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
    final s = context.read<SettingsCubit>().state.settingsModel;
    context.read<DailyPrayerContextCubit>().fetchDailyPrayerContext(
      silent: true,
      method: s.calculationMethod,
      school: s.asrSchool,
    );
    context.read<AlertsSyncCubit>().requestSync();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
