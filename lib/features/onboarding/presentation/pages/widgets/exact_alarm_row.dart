import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_status_badge.dart';
import 'package:quran_app/features/notifications/domain/entities/system_settings_target.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';

class ExactAlarmRow extends StatelessWidget {
  const ExactAlarmRow({super.key, required this.allowed});

  final bool allowed;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final muted = Colors.white.withValues(alpha: 0.75);
    return Container(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 16, 12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
      ),
      child: Row(
        spacing: 12,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const HugeIcon(
            icon: HugeIcons.strokeRoundedAlarmClock,
            color: Colors.white,
            size: 22,
          ),
          Expanded(
            child: Column(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s.rel_exactAlarms,
                  style: TS.semi16.copyWith(color: Colors.white),
                ),
                Text(
                  s.onb_exactAlarmsWhy,
                  style: TS.regular14.copyWith(color: muted),
                ),
                if (allowed)
                  AppStatusBadge(label: s.rel_allowed, color: Colors.white)
                else
                  OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size(0, 48),
                      foregroundColor: Colors.white,
                      side: BorderSide(
                        color: Colors.white.withValues(alpha: 0.5),
                      ),
                    ),
                    onPressed: () => context
                        .read<ReliabilityCubit>()
                        .openSettings(SystemSettingsTarget.exactAlarm),
                    child: Text(s.rel_openSettings, style: TS.semi14),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
