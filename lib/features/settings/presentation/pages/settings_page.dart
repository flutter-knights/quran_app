import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/feature_flags.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/settings/presentation/pages/widgets/palette_picker_widget.dart';
import 'package:quran_app/generated/l10n.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        title: Text(S.current.settings, style: TS.bold20.cairo),
        backgroundColor: scheme.surface,
      ),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final settings = state.settingsModel;
          return ListView(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 16, 16, 32),
            children: [
              AppSectionHeader(label: S.of(context).appearance_section),
              const SizedBox(height: 10),
              PalettePickerWidget(
                currentPalette: settings.palette,
                onSelect: (p) => sl<SettingsCubit>().updatePalette(p),
              ),
              const SizedBox(height: 24),
              AppSectionHeader(label: S.of(context).general_section),
              const SizedBox(height: 10),
              SurfaceCard(
                child: Column(
                  children: [
                    _SelectorRow(
                      icon: HugeIcons.strokeRoundedClock01,
                      label: S.current.twentyFourHourFormat,
                      selector: AppSegmentedSelector<bool>(
                        selected: settings.isFormat12Hours,
                        onChanged: (v) => sl<SettingsCubit>()
                            .updateSettings(isFormat12Hours: v),
                        options: [
                          SegmentOption(value: false, label: S.of(context).time_format_12h),
                          SegmentOption(value: true, label: S.of(context).time_format_24h),
                        ],
                      ),
                    ),
                    Container(
                      height: 1,
                      color: scheme.onSurface.withValues(alpha: 0.06),
                    ),
                    _SelectorRow(
                      icon: HugeIcons.strokeRoundedLanguageSquare,
                      label: S.current.arabicLanguage,
                      selector: AppSegmentedSelector<bool>(
                        selected: settings.isArabic,
                        onChanged: (v) =>
                            sl<SettingsCubit>().updateSettings(isArabic: v),
                        options: [
                          SegmentOption(value: true, label: S.of(context).language_arabic),
                          SegmentOption(value: false, label: S.of(context).language_english),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              if (FeatureFlags.pinnedPrayerStripUi) ...[
                const SizedBox(height: 24),
                AppSectionHeader(label: S.current.notifications),
                const SizedBox(height: 10),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: ListTile(
                    leading: HugeIcon(
                      icon: HugeIcons.strokeRoundedNotification01,
                      color: scheme.secondary,
                      size: 22,
                    ),
                    title: Text(
                      S.current.notifications,
                      style: TS.regular16.cairo,
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.push(AppRouter.notificationsPath),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _SelectorRow extends StatelessWidget {
  const _SelectorRow({
    required this.icon,
    required this.label,
    required this.selector,
  });

  final List<List<dynamic>> icon;
  final String label;
  final Widget selector;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          HugeIcon(icon: icon, color: scheme.onSurface, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(label, style: TS.regular16.cairo),
          ),
          selector,
        ],
      ),
    );
  }
}
