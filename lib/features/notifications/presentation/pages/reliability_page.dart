import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/palette_context.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/app_settings_tile.dart';
import 'package:quran_app/core/widgets/design/app_status_badge.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/entities/system_settings_target.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_state.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_list_parts.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/open_setting_button.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/reload_status_on_sync.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/test_adhan_button.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/xiaomi_checklist.dart';
import 'package:quran_app/features/notifications/presentation/utils/enum_localization.dart';
import 'package:skeletonizer/skeletonizer.dart';

class ReliabilityPage extends StatelessWidget {
  const ReliabilityPage({super.key});

  static const _placeholder = ReliabilityStatus(
    notificationsEnabled: true,
    channelBlocked: false,
    exactAlarmsAllowed: true,
    batteryUnrestricted: true,
    isXiaomi: false,
    usesAlarmClock: true,
  );

  @override
  Widget build(BuildContext context) {
    return ReloadStatusOnSync(
      child: Scaffold(
        backgroundColor: context.colorScheme.surface,
        body: SafeArea(
          child: Column(
            children: [
              AppScreenAppBar(title: PendingS.of(context).rel_title),
              Expanded(
                child: BlocBuilder<ReliabilityCubit, ReliabilityState>(
                  builder: (context, state) => ListView(
                    padding: const EdgeInsetsDirectional.fromSTEB(
                      16,
                      8,
                      16,
                      32,
                    ),
                    children: [
                      ...switch (state) {
                        ReliabilityLoaded(:final status) => _sections(status),
                        ReliabilityLoading() => [
                          const Skeletonizer(
                            child: _ChecksCard(status: _placeholder),
                          ),
                        ],
                        ReliabilityUnavailable() => const [],
                      },
                      const SizedBox(height: 24),
                      TestAdhanButton(label: PendingS.of(context).rel_test),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  List<Widget> _sections(ReliabilityStatus status) {
    final android = defaultTargetPlatform == TargetPlatform.android;
    return [
      _ChecksCard(status: status),
      if (android && status.isXiaomi) ...[
        const SizedBox(height: 24),
        const _XiaomiSection(),
      ],
      if (android) ...[
        const SizedBox(height: 24),
        _ScheduledCard(until: status.scheduledUntil),
      ],
    ];
  }
}

class _ChecksCard extends StatelessWidget {
  const _ChecksCard({required this.status});

  final ReliabilityStatus status;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final android = defaultTargetPlatform == TargetPlatform.android;
    final notificationsOk =
        status.notificationsEnabled && !status.channelBlocked;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          _CheckRow(
            icon: HugeIcons.strokeRoundedNotification01,
            title: s.rel_notifications,
            value: notificationsOk ? s.rel_allowed : s.rel_blocked,
            ok: notificationsOk,
            target: SystemSettingsTarget.notifications,
          ),
          if (android) ...[
            const AlertsRowDivider(),
            _CheckRow(
              icon: HugeIcons.strokeRoundedAlarmClock,
              title: s.rel_exactAlarms,
              value: status.exactAlarmsAllowed ? s.rel_allowed : s.rel_blocked,
              ok: status.exactAlarmsAllowed,
              target: SystemSettingsTarget.exactAlarm,
            ),
            const AlertsRowDivider(),
            _CheckRow(
              icon: HugeIcons.strokeRoundedBatteryCharging01,
              title: s.rel_battery,
              value: status.batteryUnrestricted
                  ? s.rel_batteryUnrestricted
                  : s.rel_batteryRestricted,
              ok: status.batteryUnrestricted,
              target: SystemSettingsTarget.battery,
              hint: s.rel_batteryHint,
            ),
          ],
        ],
      ),
    );
  }
}

class _CheckRow extends StatelessWidget {
  const _CheckRow({
    required this.icon,
    required this.title,
    required this.value,
    required this.ok,
    required this.target,
    this.hint,
  });

  final List<List<dynamic>> icon;
  final String title;
  final String value;
  final bool ok;
  final SystemSettingsTarget target;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final scheme = context.colorScheme;
    final ink = context.palette.primaryInk;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        AppSettingsTile(
          leading: HugeIcon(icon: icon, color: scheme.onSurface, size: 20),
          title: title,
          subtitle: value,
          trailing: AppStatusBadge(
            label: ok ? s.rel_working : s.rel_needsAction,
            color: ok ? ink : scheme.onSurfaceVariant,
          ),
        ),
        if (!ok)
          Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(48, 0, 16, 12),
            child: Column(
              spacing: 8,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hint case final hint?)
                  Text(
                    hint,
                    style: TS.regular14.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                OpenSettingButton(target: target, ink: ink),
              ],
            ),
          ),
      ],
    );
  }
}

class _XiaomiSection extends StatelessWidget {
  const _XiaomiSection();

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(label: s.rel_xiaomiSection),
        AlertsNote(
          text: s.rel_unverifiable,
          padding: const EdgeInsetsDirectional.fromSTEB(4, 10, 4, 10),
        ),
        XiaomiChecklist(ink: context.palette.primaryInk),
      ],
    );
  }
}

class _ScheduledCard extends StatelessWidget {
  const _ScheduledCard({required this.until});

  final DateTime? until;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final until = this.until;
    return SurfaceCard(
      padding: EdgeInsets.zero,
      child: AppSettingsTile(
        leading: HugeIcon(
          icon: HugeIcons.strokeRoundedCalendar03,
          color: context.colorScheme.onSurface,
          size: 20,
        ),
        title: until == null
            ? s.rel_scheduledNone
            : s.rel_scheduledUntil(alertsDateLabel(until, context.langCode)),
        subtitle: s.rel_scheduledSub,
      ),
    );
  }
}
