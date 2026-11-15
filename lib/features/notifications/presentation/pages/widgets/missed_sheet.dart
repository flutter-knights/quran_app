import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/palette_context.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/notifications/domain/services/alerts_prompt_picker.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_sheet_actions.dart';
import 'package:quran_app/features/notifications/presentation/utils/enum_localization.dart';

class MissedSheet extends StatelessWidget {
  const MissedSheet({
    super.key,
    required this.kind,
    required this.prayer,
    required this.isXiaomi,
  });

  final AlertsPrompt kind;
  final PrayerName prayer;
  final bool isXiaomi;

  static Future<void> show(
    BuildContext context, {
    required AlertsPrompt kind,
    required PrayerName prayer,
    required bool isXiaomi,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.colorScheme.surface,
      builder: (_) =>
          MissedSheet(kind: kind, prayer: prayer, isXiaomi: isXiaomi),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final scheme = context.colorScheme;
    final ink = context.palette.primaryInk;
    final name = prayerLabel(context, prayer);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(24, 0, 24, 16),
      child: Column(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: ink.withValues(alpha: 0.12),
            ),
            child: HugeIcon(
              icon: HugeIcons.strokeRoundedClock01,
              color: ink,
              size: 22,
            ),
          ),
          Text(
            kind == AlertsPrompt.late
                ? s.late_title(name)
                : s.missed_title(name),
            style: TS.semi20.copyWith(color: scheme.onSurface),
          ),
          Text(
            isXiaomi ? s.missed_body : s.missed_bodyGeneric,
            style: TS.regular14.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          AlertsSheetActions(
            primaryLabel: s.missed_fix,
            laterLabel: s.onb_later,
            onPrimary: () {
              final router = GoRouter.of(context);
              Navigator.of(context).pop();
              router.push(AppRouter.alertsReliabilityPath);
            },
          ),
        ],
      ),
    );
  }
}
