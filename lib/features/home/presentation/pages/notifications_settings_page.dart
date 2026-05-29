import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/per_prayer_adhan_tile.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/test_adhan_button.dart';
import 'package:quran_app/generated/l10n.dart';

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
