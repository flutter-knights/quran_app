import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/core/widgets/design/splash_backdrop.dart';
import 'package:quran_app/features/onboarding/presentation/pages/widgets/appearance_step.dart';
import 'package:quran_app/features/onboarding/presentation/pages/widgets/language_step.dart';
import 'package:quran_app/features/onboarding/presentation/pages/widgets/permission_step.dart';
import 'package:quran_app/features/onboarding/presentation/pages/widgets/welcome_step.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

/// First-run onboarding wizard. Five steps over the shared [SplashBackdrop]
/// (so the splash animates into it). Preferences apply live via [SettingsCubit];
/// the two permission steps prompt the OS but always proceed (never trap the
/// user). Finishing marks onboarding complete and replaces with home.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  static const _stepCount = 5;
  static const _locationStep = 3;
  static const _notificationsStep = 4;

  final _controller = PageController();
  int _index = 0;
  bool _leaving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _goTo(int i) {
    _controller.animateToPage(
      i,
      duration: const Duration(milliseconds: 350),
      curve: Curves.easeInOutCubic,
    );
  }

  Future<void> _onPrimary() async {
    switch (_index) {
      case _locationStep:
        try {
          await Geolocator.requestPermission();
        } catch (_) {}
        if (mounted) _goTo(_notificationsStep);
      case _notificationsStep:
        try {
          await sl<PrayerNotificationScheduler>().requestNotificationsPermission();
        } catch (_) {}
        _finish();
      default:
        _goTo(_index + 1);
    }
  }

  void _finish() {
    if (_leaving || !mounted) return;
    _leaving = true;
    context.read<SettingsCubit>().completeOnboarding();
    GoRouter.of(context).pushReplacement(AppRouter.homePath);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Scaffold(
      body: SplashBackdrop(
        child: SafeArea(
          child: Column(
            children: [
              SizedBox(
                height: 44,
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: _index == 0
                      ? null
                      : IconButton(
                          onPressed: () => _goTo(_index - 1),
                          icon: const Icon(Icons.arrow_back_ios_new, size: 18),
                          color: Colors.white.withValues(alpha: 0.8),
                        ),
                ),
              ),
              Expanded(
                child: PageView(
                  controller: _controller,
                  onPageChanged: (i) => setState(() => _index = i),
                  children: [
                    const WelcomeStep(),
                    const LanguageStep(),
                    const AppearanceStep(),
                    PermissionStep(
                      icon: HugeIcons.strokeRoundedLocation01,
                      title: s.onb_location_title,
                      why: s.onb_location_why,
                    ),
                    PermissionStep(
                      icon: HugeIcons.strokeRoundedNotification01,
                      title: s.onb_notifications_title,
                      why: s.onb_notifications_why,
                    ),
                  ],
                ),
              ),
              _ProgressDots(count: _stepCount, index: _index),
              const SizedBox(height: 16),
              _actions(s),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Widget _actions(S s) {
    final isPermissionStep =
        _index == _locationStep || _index == _notificationsStep;
    final primaryLabel = isPermissionStep ? s.onb_enable : s.onb_continue;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: _onPrimary,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: Theme.of(context).colorScheme.primary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Text(primaryLabel, style: TS.bold16),
            ),
          ),
          if (isPermissionStep)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: TextButton(
                onPressed: () => _index == _locationStep
                    ? _goTo(_notificationsStep)
                    : _finish(),
                child: Text(
                  s.onb_not_now,
                  style: TS.semi14.copyWith(
                    color: Colors.white.withValues(alpha: 0.7),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _ProgressDots extends StatelessWidget {
  const _ProgressDots({required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(count, (i) {
        final active = i == index;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: active ? 18 : 6,
          height: 6,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: active ? 1 : 0.3),
            borderRadius: BorderRadius.circular(3),
          ),
        );
      }),
    );
  }
}
