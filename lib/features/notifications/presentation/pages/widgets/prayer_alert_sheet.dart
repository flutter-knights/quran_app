import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/app_settings_tile.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/home/domain/entities/prayer_times.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_cubit.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_list_parts.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_switch_row.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/reminder_picker.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/sound_picker.dart';
import 'package:quran_app/features/notifications/presentation/utils/enum_localization.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class PrayerAlertSheet extends StatelessWidget {
  const PrayerAlertSheet({super.key, required this.prayer});

  final PrayerName prayer;

  static Future<void> show(BuildContext context, PrayerName prayer) {
    final today = context.read<TodayPrayerTimesCubit>();
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: context.colorScheme.surface,
      builder: (_) => BlocProvider.value(
        value: today,
        child: PrayerAlertSheet(prayer: prayer),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocSelector<SettingsCubit, SettingsState, (PrayerAlert, bool)>(
      selector: (state) => (
        state.settingsModel.prayerAlerts[prayer] ?? const PrayerAlert(),
        state.settingsModel.is24HourFormat,
      ),
      builder: (context, data) =>
          BlocSelector<TodayPrayerTimesCubit, PrayerTimes?, String?>(
            selector: (today) => today?.timings[prayer],
            builder: (context, rawTime) => _SheetBody(
              prayer: prayer,
              alert: data.$1,
              use24Hour: data.$2,
              rawTime: rawTime,
            ),
          ),
    );
  }
}

class _SheetBody extends StatelessWidget {
  const _SheetBody({
    required this.prayer,
    required this.alert,
    required this.use24Hour,
    required this.rawTime,
  });

  final PrayerName prayer;
  final PrayerAlert alert;
  final bool use24Hour;
  final String? rawTime;

  void _update(BuildContext context, PrayerAlert next) =>
      context.read<SettingsCubit>().updatePrayerAlert(prayer, next);

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final scheme = context.colorScheme;
    final lang = context.langCode;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final reminderActive = alert.enabled && alert.reminderEnabled;
    final ringable = alert.sound == PrayerSound.adhan;
    final time = prayerTimeLabel(
      rawTime,
      use24Hour: use24Hour,
      localeCode: lang,
    );
    final chevron = HugeIcon(
      icon: forwardArrowIcon(context),
      color: scheme.onSurfaceVariant,
      size: 20,
    );
    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(
        16,
        0,
        16,
        16 + MediaQuery.viewPaddingOf(context).bottom,
      ),
      child: Column(
        spacing: 8,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            spacing: 10,
            children: [
              Text(
                prayerLabel(context, prayer),
                style: TS.semi20.copyWith(color: scheme.onSurface),
              ),
              if (time != null)
                Text(
                  time,
                  style: TS.regular14.copyWith(color: scheme.onSurfaceVariant),
                ),
              const Spacer(),
              IconButton(
                tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
                onPressed: () => Navigator.of(context).pop(),
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedCancel01,
                  color: scheme.onSurfaceVariant,
                  size: 22,
                ),
              ),
            ],
          ),
          Column(
            spacing: 24,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Column(
                spacing: 10,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSectionHeader(label: s.alerts_sheet_atTime),
                  SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        AlertsSwitchRow(
                          title: s.alerts_sheet_alertSwitch,
                          value: alert.enabled,
                          onChanged: (v) =>
                              _update(context, alert.copyWith(enabled: v)),
                        ),
                        const AlertsRowDivider(),
                        AppSettingsTile(
                          title: s.alerts_sheet_sound,
                          subtitle: prayerSoundLabel(
                            s,
                            alert.sound,
                            prayer: prayer,
                            ios: ios,
                          ),
                          trailing: chevron,
                          enabled: alert.enabled,
                          onTap: () => showPrayerSoundPicker(context, prayer),
                        ),
                        if (!ios) ...[
                          const AlertsRowDivider(),
                          AlertsSwitchRow(
                            title: s.alerts_sheet_ringInSilent,
                            subtitle: s.alerts_sheet_ringInSilentSub,
                            value: alert.ringInSilent && ringable,
                            onChanged: alert.enabled && ringable
                                ? (v) => _update(
                                    context,
                                    alert.copyWith(ringInSilent: v),
                                  )
                                : null,
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (ios)
                    AlertsNote(
                      padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 16,
                      ),
                      text: s.alerts_sheet_iosNote,
                    ),
                ],
              ),
              Column(
                spacing: 10,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AppSectionHeader(label: s.alerts_sheet_beforeTime),
                  SurfaceCard(
                    padding: EdgeInsets.zero,
                    child: Column(
                      children: [
                        AlertsSwitchRow(
                          title: s.alerts_sheet_reminderSwitch,
                          value: reminderActive,
                          onChanged: alert.enabled
                              ? (v) => _update(
                                  context,
                                  alert.copyWith(reminderEnabled: v),
                                )
                              : null,
                        ),
                        if (alert.enabled)
                          ReminderPicker(
                            minutes: alert.reminderMinutes,
                            enabled: reminderActive,
                            rawTime: rawTime,
                            use24Hour: use24Hour,
                            onCommit: (m) => _update(
                              context,
                              alert.copyWith(reminderMinutes: m),
                            ),
                          )
                        else
                          AlertsNote(
                            padding: _notePadding,
                            text: s.alerts_sheet_reminderDisabled,
                          ),
                        const AlertsRowDivider(),
                        AppSettingsTile(
                          title: s.alerts_sheet_reminderSound,
                          subtitle: reminderSoundLabel(
                            s,
                            alert.reminderSound,
                            ios: ios,
                          ),
                          trailing: chevron,
                          enabled: reminderActive,
                          onTap: () => showReminderSoundPicker(context, prayer),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

const _notePadding = EdgeInsetsDirectional.fromSTEB(16, 10, 16, 10);
