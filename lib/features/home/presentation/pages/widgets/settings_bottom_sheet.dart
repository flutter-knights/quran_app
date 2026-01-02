import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:gap/gap.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/setting_switch.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

void showSettings(BuildContext context) {
  showModalBottomSheet(
    context: context,
    builder: (_) => const SettingsBottomSheet(),
    isScrollControlled: false,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
    ),
    useSafeArea: true,
  );
}

class SettingsBottomSheet extends StatelessWidget {
  const SettingsBottomSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final settings = state.settingsModel;
        return Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.start,
            spacing: 8,
            children: [
              Text(S.current.settings, style: TS.bold20.cairo),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 28,
                  vertical: 16,
                ),
                child: Divider(color: context.colorScheme.primary),
              ),
              SettingSwitch(
                settings: settings,
                settingTitle: S.current.darkMode,
                icons: const [
                  HugeIcons.strokeRoundedSun01,
                  HugeIcons.strokeRoundedMoon01,
                ],
                value: settings.isDarkMode,
                action: () => sl<SettingsCubit>().updateSettings(
                  isDarkMode: !settings.isDarkMode,
                ),
              ),
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
              const Gap(48),
            ],
          ),
        );
      },
    );
  }
}
