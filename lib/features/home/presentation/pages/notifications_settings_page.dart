import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/setting_switch.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class NotificationsSettingsPage extends StatelessWidget {
  const NotificationsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(S.current.notifications, style: TS.bold20.cairo),
        backgroundColor: context.colorScheme.surface,
      ),
      body: SafeArea(
        child: BlocBuilder<SettingsCubit, SettingsState>(
          builder: (context, state) {
            final settings = state.settingsModel;
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                SettingSwitch(
                  settings: settings,
                  settingTitle: S.current.pinnedPrayerTimes,
                  icons: const [
                    HugeIcons.strokeRoundedNotification01,
                    HugeIcons.strokeRoundedNotificationOff01,
                  ],
                  value: settings.isPrayerStripPinned,
                  action: () => sl<SettingsCubit>().updatePrayerStripPinned(
                    !settings.isPrayerStripPinned,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Text(
                    S.current.pinnedPrayerTimesSubtitle,
                    style: TS.regular14.cairo.copyWith(
                      color: context.colorScheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
