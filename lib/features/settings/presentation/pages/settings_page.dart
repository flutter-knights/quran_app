import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/feature_flags.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/setting_switch.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/settings/presentation/pages/widgets/palette_picker_widget.dart';
import 'package:quran_app/generated/l10n.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      appBar: AppBar(
        title: Text(S.current.settings, style: TS.bold20.cairo),
        backgroundColor: context.colorScheme.surface,
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final settings = state.settingsModel;
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 24, 16, 24),
            children: [
              _SectionLabel('APPEARANCE'),
              const SizedBox(height: 8),
              PalettePickerWidget(
                currentPalette: settings.palette,
                onSelect: (p) => sl<SettingsCubit>().updatePalette(p),
              ),
              const SizedBox(height: 24),
              _SectionLabel('GENERAL'),
              const SizedBox(height: 8),
              SettingSwitch(
                settings: settings,
                settingTitle: S.current.twentyFourHourFormat,
                icons: const [
                  HugeIcons.strokeRoundedClock01,
                  HugeIcons.strokeRoundedTimeQuarterPass,
                ],
                value: settings.isFormat12Hours,
                action: () => sl<SettingsCubit>().updateSettings(
                  isFormat12Hours: !settings.isFormat12Hours,
                ),
              ),
              SettingSwitch(
                settings: settings,
                settingTitle: S.current.arabicLanguage,
                icons: const [
                  HugeIcons.strokeRoundedLanguageSquare,
                  HugeIcons.strokeRoundedLanguageSquare,
                ],
                value: settings.isArabic,
                action: () => sl<SettingsCubit>().updateSettings(
                  isArabic: !settings.isArabic,
                ),
              ),
              if (FeatureFlags.pinnedPrayerStripUi) ...[
                const SizedBox(height: 24),
                _SectionLabel('NOTIFICATIONS'),
                const SizedBox(height: 8),
                ListTile(
                  leading: const HugeIcon(
                    icon: HugeIcons.strokeRoundedNotification01,
                    size: 24,
                  ),
                  title: Text(
                    S.current.notifications,
                    style: TS.regular16.cairo,
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => context.push(AppRouter.notificationsPath),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.label);
  final String label;

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: TextStyle(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: context.colorScheme.onSurfaceVariant,
        letterSpacing: 1.2,
      ),
    );
  }
}
