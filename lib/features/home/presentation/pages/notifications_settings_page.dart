import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/per_prayer_adhan_tile.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/test_adhan_button.dart';
import 'package:quran_app/generated/l10n.dart';

/// Shown at the top of the notifications settings page when the OS has
/// notifications disabled for the app. Refreshes itself on resume so it
/// disappears once the user enables notifications from system settings.
///
/// Action mechanism: no `app_settings` or `permission_handler` package is
/// available in pubspec.yaml, so the action calls
/// [PrayerNotificationScheduler.requestNotificationsPermission] (best-effort:
/// re-prompts on Android 13+ when not permanently denied; silent otherwise).
class _NotifDisabledBanner extends StatefulWidget {
  const _NotifDisabledBanner();

  @override
  State<_NotifDisabledBanner> createState() => _NotifDisabledBannerState();
}

class _NotifDisabledBannerState extends State<_NotifDisabledBanner>
    with WidgetsBindingObserver {
  bool _enabled = true; // assume enabled until checked (hides by default)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final enabled =
          await sl<PrayerNotificationScheduler>().areNotificationsEnabled();
      if (mounted) setState(() => _enabled = enabled);
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    if (_enabled) return const SizedBox.shrink();
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: SurfaceCard(
        child: Row(
          children: [
            Expanded(
              child: Text(
                S.of(context).notifSettings_disabledBanner_text,
                style: TS.regular14.copyWith(color: scheme.onSurface),
              ),
            ),
            TextButton(
              onPressed: () async {
                await sl<PrayerNotificationScheduler>()
                    .requestNotificationsPermission();
                await _refresh();
              },
              child: Text(S.of(context).notifSettings_disabledBanner_action),
            ),
          ],
        ),
      ),
    );
  }
}

/// Adhan & reminders settings. The pinned-strip toggle now lives in the main
/// settings page; this screen is focused on per-prayer adhan + reminder offsets.
class NotificationsSettingsPage extends StatelessWidget {
  const NotificationsSettingsPage({super.key});

  static const List<PrayerName> _orderedPrayers = [
    PrayerName.fajr,
    PrayerName.dhuhr,
    PrayerName.asr,
    PrayerName.maghrib,
    PrayerName.isha,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenAppBar(title: S.current.adhan_and_reminders),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
                children: [
                  const _NotifDisabledBanner(),
                  AppSectionHeader(label: S.of(context).adhanPerPrayerSection),
                  const SizedBox(height: 10),
                  SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (var i = 0; i < _orderedPrayers.length; i++)
                          PerPrayerAdhanTile(
                            prayer: _orderedPrayers[i],
                            showTopDivider: i > 0,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  AppSectionHeader(label: S.of(context).test_section),
                  const SizedBox(height: 10),
                  const TestAdhanButton(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
