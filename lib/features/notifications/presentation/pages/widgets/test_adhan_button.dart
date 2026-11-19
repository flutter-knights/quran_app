import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/palette_context.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/usecases/schedule_test_adhan.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_state.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class TestAdhanButton extends StatelessWidget {
  const TestAdhanButton({super.key, required this.label});

  final String label;

  Future<void> _onPressed(BuildContext context) async {
    final s = PendingS.current;
    final messenger = ScaffoldMessenger.of(context);
    final reliability = context.read<ReliabilityCubit>().state;
    if (reliability case ReliabilityLoaded(
      :final status,
    ) when !status.notificationsEnabled) {
      messenger.showSnackBar(
        SnackBar(content: Text(s.alerts_testBlocked, style: TS.regular14)),
      );
      return;
    }
    final exactDenied = switch (reliability) {
      ReliabilityLoaded(:final status) => !status.exactAlarmsAllowed,
      _ => false,
    };
    final settings = context.read<SettingsCubit>().state.settingsModel;
    final result = await sl<ScheduleTestAdhan>()(
      ScheduleTestAdhanParams(
        alert: settings.prayerAlerts[PrayerName.dhuhr] ?? const PrayerAlert(),
        localeCode: settings.isArabic ? 'ar' : 'en',
      ),
    );
    final message = switch (result.isRight()) {
      true when exactDenied => s.upg_exactAlarms,
      true => s.alerts_testCaption,
      false => s.alerts_testFailed,
    };
    messenger.showSnackBar(
      SnackBar(content: Text(message, style: TS.regular14)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return OutlinedButton.icon(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size.fromHeight(48),
        foregroundColor: scheme.onSurface,
        side: BorderSide(color: scheme.onSurfaceVariant.withValues(alpha: 0.4)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      onPressed: () => _onPressed(context),
      icon: HugeIcon(
        icon: HugeIcons.strokeRoundedPlayCircle,
        color: context.palette.primaryInk,
        size: 22,
      ),
      label: Text(label, style: TS.semi16),
    );
  }
}
