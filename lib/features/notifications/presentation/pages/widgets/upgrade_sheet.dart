import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/palette_context.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_sheet_actions.dart';

class UpgradeSheet extends StatelessWidget {
  const UpgradeSheet({super.key, required this.exactAlarmsAllowed});

  final bool exactAlarmsAllowed;

  static Future<void> show(
    BuildContext context, {
    required bool exactAlarmsAllowed,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.colorScheme.surface,
      builder: (_) => UpgradeSheet(exactAlarmsAllowed: exactAlarmsAllowed),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
      child: Column(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            s.upg_title,
            style: TS.semi20.copyWith(color: context.colorScheme.onSurface),
          ),
          if (!ios)
            _Line(icon: HugeIcons.strokeRoundedVolumeHigh, text: s.upg_silent),
          _Line(icon: HugeIcons.strokeRoundedTimer02, text: s.upg_reminder),
          if (!exactAlarmsAllowed)
            _Line(
              icon: HugeIcons.strokeRoundedAlarmClock,
              text: s.upg_exactAlarms,
            ),
          const SizedBox(height: 4),
          AlertsSheetActions(
            primaryLabel: s.upg_review,
            laterLabel: s.onb_later,
            onPrimary: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push(AppRouter.notificationsPath);
              if (!exactAlarmsAllowed) {
                router.push(AppRouter.alertsReliabilityPath);
              }
            },
          ),
        ],
      ),
    );
  }
}

class _Line extends StatelessWidget {
  const _Line({required this.icon, required this.text});

  final List<List<dynamic>> icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final ink = context.palette.primaryInk;
    return Row(
      spacing: 12,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: ink.withValues(alpha: 0.12),
          ),
          child: HugeIcon(icon: icon, color: ink, size: 20),
        ),
        Expanded(
          child: Text(
            text,
            style: TS.regular14.copyWith(color: scheme.onSurface),
          ),
        ),
      ],
    );
  }
}
