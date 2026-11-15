import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/helper%20functions/numeral_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_status_badge.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/notifications/domain/entities/system_settings_target.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_list_parts.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class XiaomiChecklist extends StatelessWidget {
  const XiaomiChecklist({
    super.key,
    required this.autostartConfirmed,
    required this.batteryConfirmed,
  });

  final bool autostartConfirmed;
  final bool batteryConfirmed;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final settings = context.read<SettingsCubit>();
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _XiaomiStepRow(
            step: 1,
            title: s.rel_autostart,
            subtitle: s.rel_autostartSub,
            target: SystemSettingsTarget.autostart,
            confirmed: autostartConfirmed,
            onConfirm: () => settings.setXiaomiAutostartConfirmed(true),
          ),
          const AlertsRowDivider(),
          _XiaomiStepRow(
            step: 2,
            title: s.rel_xiaomiBattery,
            subtitle: s.rel_xiaomiBatterySub,
            target: SystemSettingsTarget.xiaomiBattery,
            confirmed: batteryConfirmed,
            onConfirm: () => settings.setXiaomiBatteryConfirmed(true),
          ),
          const AlertsRowDivider(),
          _XiaomiStepRow(
            step: 3,
            title: s.rel_lockApp,
            subtitle: s.rel_lockAppSub,
          ),
        ],
      ),
    );
  }
}

class _XiaomiStepRow extends StatelessWidget {
  const _XiaomiStepRow({
    required this.step,
    required this.title,
    required this.subtitle,
    this.target,
    this.confirmed = false,
    this.onConfirm,
  });

  final int step;
  final String title;
  final String subtitle;
  final SystemSettingsTarget? target;
  final bool confirmed;
  final VoidCallback? onConfirm;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final scheme = context.colorScheme;
    final ink = Theme.of(context).brightness == Brightness.dark
        ? scheme.secondary
        : scheme.primary;
    final target = this.target;
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
      child: Row(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _StepMarker(step: step, confirmed: confirmed, ink: ink),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: TS.semi16.copyWith(color: scheme.onSurface)),
                Text(
                  subtitle,
                  style: TS.regular14.copyWith(color: scheme.onSurfaceVariant),
                ),
                if (target != null) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: ink,
                          side: BorderSide(color: ink.withValues(alpha: 0.5)),
                        ),
                        onPressed: () => context
                            .read<ReliabilityCubit>()
                            .openSettings(target),
                        child: Text(s.rel_openSettings, style: TS.semi14),
                      ),
                      if (confirmed)
                        AppStatusBadge(label: s.rel_done, color: ink)
                      else
                        TextButton(
                          style: TextButton.styleFrom(
                            minimumSize: const Size(48, 48),
                            foregroundColor: ink,
                          ),
                          onPressed: () {
                            onConfirm?.call();
                            context.read<ReliabilityCubit>().load();
                          },
                          child: Text(s.rel_done, style: TS.semi14),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StepMarker extends StatelessWidget {
  const _StepMarker({
    required this.step,
    required this.confirmed,
    required this.ink,
  });

  final int step;
  final bool confirmed;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: ink.withValues(alpha: confirmed ? 0.16 : 0.08),
      ),
      child: confirmed
          ? HugeIcon(icon: HugeIcons.strokeRoundedTick02, color: ink, size: 16)
          : Text(
              '$step'.toIndicNumerals(context.langCode),
              style: TS.semi14.copyWith(color: ink),
            ),
    );
  }
}
