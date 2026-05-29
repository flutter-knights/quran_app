import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/reminder_offset_dropdown.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

/// One row per prayer: localized label + adhan switch + reminder offset dropdown.
/// When the switch is off the dropdown is shown muted and disabled.
class PerPrayerAdhanTile extends StatelessWidget {
  final PrayerName prayer;
  final bool showTopDivider;

  const PerPrayerAdhanTile({
    super.key,
    required this.prayer,
    this.showTopDivider = false,
  });

  String _localizedName(BuildContext context) {
    switch (prayer) {
      case PrayerName.fajr: return S.of(context).fajr;
      case PrayerName.dhuhr: return S.of(context).dhuhr;
      case PrayerName.asr: return S.of(context).asr;
      case PrayerName.maghrib: return S.of(context).maghrib;
      case PrayerName.isha: return S.of(context).isha;
      case PrayerName.sunrise: return '';
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, state) {
        final s = state.settingsModel;
        final adhanOn = s.adhanEnabledByPrayer[prayer] ?? true;
        final reminderMinutes = s.reminderMinutesByPrayer[prayer] ?? 0;

        return Column(
          children: [
            if (showTopDivider)
              Container(
                height: 1,
                color: context.colorScheme.onSurface.withValues(alpha: 0.06),
              ),
            Padding(
              padding: const EdgeInsetsDirectional.fromSTEB(16, 12, 12, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _localizedName(context),
                          style: TS.bold16.cairo.copyWith(
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      Switch(
                        value: adhanOn,
                        onChanged: (v) =>
                            sl<SettingsCubit>().updateAdhanEnabled(prayer, v),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Text(
                        S.of(context).reminderLabel,
                        style: TS.regular14.cairo.copyWith(
                          color: context.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 12),
                      ReminderOffsetDropdown(
                        value: reminderMinutes,
                        enabled: adhanOn,
                        onChanged: (v) => sl<SettingsCubit>()
                            .updateReminderMinutes(prayer, v),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}
