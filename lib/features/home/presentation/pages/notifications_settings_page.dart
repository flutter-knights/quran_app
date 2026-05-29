import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/per_prayer_adhan_tile.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/setting_switch.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/test_adhan_button.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

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
            AppScreenAppBar(title: S.current.notifications),
            Expanded(
              child: BlocBuilder<SettingsCubit, SettingsState>(
                builder: (context, state) {
                  final settings = state.settingsModel;
                  return ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      16,
                      16,
                      32,
                    ),
                    children: [
                      const _Header(),
                      const SizedBox(height: 14),
                      SurfaceCard(
                        padding: EdgeInsets.zero,
                        child: SettingSwitch(
                          settings: settings,
                          settingTitle: S.current.pinnedPrayerTimes,
                          icons: const [
                            HugeIcons.strokeRoundedNotification01,
                            HugeIcons.strokeRoundedNotificationOff01,
                          ],
                          value: settings.isPrayerStripPinned,
                          action: () =>
                              sl<SettingsCubit>().updatePrayerStripPinned(
                                !settings.isPrayerStripPinned,
                              ),
                        ),
                      ),
                      const SizedBox(height: 18),
                      AppSectionHeader(
                        label: S.of(context).adhanPerPrayerSection,
                      ),
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
                      const SizedBox(height: 18),
                      const TestAdhanButton(),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.surfaceContainer,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: scheme.onSurface.withValues(alpha: 0.06),
              ),
            ),
            alignment: Alignment.center,
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedNotification01,
              color: scheme.primary,
              size: 26,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                S.current.notificationsScreenSubtitle,
                style: TS.regular14.cairo.copyWith(
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
