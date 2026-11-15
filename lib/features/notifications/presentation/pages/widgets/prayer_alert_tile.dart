import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/palette_context.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_settings_tile.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_cubit.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/alerts_list_parts.dart';
import 'package:quran_app/features/notifications/presentation/cubit/today_prayer_times_state.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/prayer_alert_sheet.dart';
import 'package:quran_app/features/notifications/presentation/utils/enum_localization.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class PrayerAlertTile extends StatelessWidget {
  const PrayerAlertTile({super.key, required this.prayer});

  final PrayerName prayer;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final lang = context.langCode;
    final scheme = context.colorScheme;
    final ios = defaultTargetPlatform == TargetPlatform.iOS;
    final ink = context.palette.primaryInk;
    return BlocSelector<SettingsCubit, SettingsState, (PrayerAlert, bool)>(
      selector: (state) => (
        state.settingsModel.prayerAlerts[prayer] ?? const PrayerAlert(),
        state.settingsModel.is24HourFormat,
      ),
      builder: (context, data) {
        final (alert, use24Hour) = data;
        final active = alert.enabled && alert.sound != PrayerSound.silent;
        return AppSettingsTile(
          leading: HugeIcon(
            icon: prayerAlertIcon(alert),
            color: active ? ink : scheme.onSurfaceVariant,
            size: 22,
          ),
          title: prayerLabel(context, prayer),
          subtitle: alertSummary(
            s,
            alert,
            prayer: prayer,
            ios: ios,
            localeCode: lang,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: [
              BlocSelector<
                TodayPrayerTimesCubit,
                TodayPrayerTimesState,
                String?
              >(
                selector: (today) => prayerTimeLabel(
                  today.times?.timings[prayer],
                  use24Hour: use24Hour,
                  localeCode: lang,
                ),
                builder: (context, time) => time == null
                    ? const SizedBox.shrink()
                    : Text(
                        time,
                        style: TS.regular14.copyWith(
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
              const AlertsChevron(),
            ],
          ),
          onTap: () => PrayerAlertSheet.show(context, prayer),
        );
      },
    );
  }
}
