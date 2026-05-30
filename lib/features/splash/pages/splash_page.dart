import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/assets_dir.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/widgets/design/splash_backdrop.dart';
import 'package:quran_app/core/widgets/design/splash_loader.dart';
import 'package:quran_app/features/home/domain/usecases/get_daily_prayer_context.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/splash/pages/widgets/slogan_animation.dart';

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  StreamSubscription<Object?>? _warmupSub;

  /// Drives the exit choreography: the wordmark lifts away and the dots fade,
  /// then the next screen slides/fades in.
  bool _exiting = false;

  void onLoaded(BuildContext context) {
    if (_exiting) return;
    setState(() => _exiting = true);
    // Capture router + destination before the async gap so we don't touch
    // `context` after the delay (lint-clean and safe across the exit anim).
    final router = GoRouter.of(context);
    // First run → onboarding wizard; otherwise straight to home.
    final onboarded =
        context.read<SettingsCubit>().state.settingsModel.hasCompletedOnboarding;
    final destination = onboarded
        ? AppRouter.homePath
        : AppRouter.onboardingPath;
    Future.delayed(const Duration(milliseconds: 450), () {
      if (!mounted) return;
      router.pushReplacement(destination);
    });
  }

  @override
  void initState() {
    super.initState();
    // Only warm the cache for returning users. On first run the splash hands
    // off to the landing, which owns the permission prompt — warming here would
    // fire `determinePosition()` → `requestPermission()` and pop the location
    // dialog over the splash, before the landing. First-run cache is cold
    // anyway, so the warm buys nothing.
    final settings = context.read<SettingsCubit>().state.settingsModel;
    if (settings.hasCompletedOnboarding) {
      _warmHomeCache(settings.calculationMethod, settings.asrSchool);
    }
  }

  /// Warms the home screen's prayer-context cache (location + prayer times)
  /// while the splash animation plays, so home renders fast from Hive on
  /// hand-off. Fire-and-forget: results are discarded — the repositories cache
  /// as a side effect — and any failure is silent (home re-fetches and shows
  /// its own loading state). Never gates navigation, so a slow GPS/network can
  /// never trap the user on the splash.
  void _warmHomeCache(CalculationMethod method, AsrSchool school) {
    try {
      _warmupSub = sl<GetDailyPrayerContext>()(
        GetDailyPrayerContextParams(method: method, school: school),
      ).listen(
        (_) {},
        onError: (_) {},
      );
    } catch (_) {
      // DI/lookup failure — preload is best-effort, home will fetch normally.
    }
  }

  @override
  void dispose() {
    _warmupSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SplashBackdrop(
        child: Stack(
          children: [
            Align(
              alignment: const Alignment(0, -0.2),
              child: AnimatedSlide(
                duration: const Duration(milliseconds: 450),
                curve: Curves.easeInCubic,
                offset: _exiting ? const Offset(0, -0.18) : Offset.zero,
                child: AnimatedOpacity(
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeIn,
                  opacity: _exiting ? 0 : 1,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Column(
                            spacing: 16,
                            children: [
                              Image.asset(
                                AssetsDir.imagesDir('logo.png'),
                                height: 156,
                                color: Colors.white,
                              ),
                              Text(
                                "اَلْقُرْآنُ الْكَرِيمُ",
                                style: TS.extra32
                                    .copyWith(color: Colors.white)
                                    .amiri,
                              ),
                            ],
                          )
                          .animate()
                          .fadeIn(duration: 2.seconds, delay: .2.seconds)
                          .scale(
                            duration: 1.5.seconds,
                            begin: const Offset(1.4, 1.4),
                            end: const Offset(1, 1),
                            curve: Curves.decelerate,
                          ),

                      const Gap(8),

                      SloganAnimation(
                        slogan: "اقْرَأْ تَعَلَّمْ احْفَظْ",
                        color: Colors.white.withValues(alpha: 0.55),
                        onLoaded: () => onLoaded(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),

            Positioned(
              bottom: 48,
              left: 0,
              right: 0,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeIn,
                opacity: _exiting ? 0 : 1,
                child: const SplashLoader(),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
