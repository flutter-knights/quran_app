import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_option_sheet.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/app_settings_tile.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_list_parts.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_status_line.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/prayer_alert_tile.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/test_adhan_button.dart';
import 'package:quran_app/features/notifications/presentation/utils/calculation_method_localization.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

class NotificationsSettingsPage extends StatelessWidget {
  const NotificationsSettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final android = defaultTargetPlatform == TargetPlatform.android;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return Scaffold(
      backgroundColor: context.colorScheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenAppBar(title: S.of(context).adhan_and_reminders),
            Expanded(
              child: ListView(
                padding: const EdgeInsetsDirectional.fromSTEB(16, 8, 16, 32),
                children: [
                  AlertsStatusLine(
                    onTap: () => context.push(AppRouter.alertsReliabilityPath),
                  ),
                  const SizedBox(height: 16),
                  AppSectionHeader(label: s.alerts_prayersSection),
                  const SizedBox(height: 10),
                  SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        for (final prayer in alertPrayers) ...[
                          if (prayer != alertPrayers.first)
                            const AlertsRowDivider(),
                          PrayerAlertTile(prayer: prayer),
                        ],
                      ],
                    ),
                  ),
                  AlertsNote(
                    text: ios ? s.alerts_iosTruth : s.alerts_silentTruth,
                  ),
                  if (android) ...[
                    const SizedBox(height: 8),
                    const SurfaceCard(
                      padding: EdgeInsets.zero,
                      child: _StripRow(),
                    ),
                  ],
                  const SizedBox(height: 24),
                  AppSectionHeader(label: s.alerts_timesSection),
                  const SizedBox(height: 10),
                  const _TimesSection(),
                  const SizedBox(height: 24),
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

class _StripRow extends StatelessWidget {
  const _StripRow();

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    return BlocSelector<SettingsCubit, SettingsState, (bool, bool)>(
      selector: (state) => (
        state.settingsModel.isPrayerStripPinned,
        state.settingsModel.stripStyle.expanded,
      ),
      builder: (context, data) {
        final (pinned, expanded) = data;
        return AppSettingsTile(
          leading: HugeIcon(
            icon: HugeIcons.strokeRoundedPin,
            color: context.colorScheme.onSurface,
            size: 20,
          ),
          title: s.alerts_stripRow_title,
          subtitle: !pinned
              ? s.alerts_stripRow_off
              : expanded
              ? s.alerts_stripRow_onExpanded
              : s.alerts_stripRow_on,
          trailing: const AlertsChevron(),
          onTap: () => context.push(AppRouter.prayerStripPath),
        );
      },
    );
  }
}

class _TimesSection extends StatelessWidget {
  const _TimesSection();

  @override
  Widget build(BuildContext context) {
    final l10n = S.of(context);
    final scheme = context.colorScheme;
    return BlocSelector<
      SettingsCubit,
      SettingsState,
      (CalculationMethod, AsrSchool)
    >(
      selector: (state) => (
        state.settingsModel.calculationMethod,
        state.settingsModel.asrSchool,
      ),
      builder: (context, data) {
        final (method, school) = data;
        final cubit = context.read<SettingsCubit>();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SurfaceCard(
              padding: EdgeInsets.zero,
              child: Column(
                children: [
                  AppSettingsTile(
                    leading: HugeIcon(
                      icon: HugeIcons.strokeRoundedLocation01,
                      color: scheme.onSurface,
                      size: 20,
                    ),
                    title: l10n.calculationMethod_methodLabel,
                    subtitle: method.localized(context),
                    trailing: const AlertsChevron(),
                    onTap: () => showAppOptionSheet(
                      context: context,
                      title: l10n.calculationMethod_methodLabel,
                      selected: method,
                      onSelected: cubit.updateCalculationMethod,
                      options: [
                        for (final m in CalculationMethod.values)
                          AppOption(value: m, label: m.localized(context)),
                      ],
                    ),
                  ),
                  const AlertsRowDivider(),
                  AppSettingsTile(
                    leading: HugeIcon(
                      icon: HugeIcons.strokeRoundedSun01,
                      color: scheme.onSurface,
                      size: 20,
                    ),
                    title: l10n.calculationMethod_schoolLabel,
                    subtitle: school.localized(context),
                    trailing: const AlertsChevron(),
                    onTap: () => showAppOptionSheet(
                      context: context,
                      title: l10n.calculationMethod_schoolLabel,
                      selected: school,
                      onSelected: cubit.updateAsrSchool,
                      options: [
                        for (final a in AsrSchool.values)
                          AppOption(value: a, label: a.localized(context)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            if (method == CalculationMethod.auto)
              AlertsNote(text: PendingS.of(context).alerts_autoMethodReason),
          ],
        );
      },
    );
  }
}
