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
import 'package:quran_app/generated/l10n.dart';

class TestAdhanButton extends StatelessWidget {
  const TestAdhanButton({super.key});

  Future<void> _onPressed(BuildContext context) async {
    final s = PendingS.current;
    final messenger = ScaffoldMessenger.of(context);
    if (context.read<ReliabilityCubit>().state case ReliabilityLoaded(
      :final status,
    ) when !status.notificationsEnabled || !status.exactAlarmsAllowed) {
      messenger.showSnackBar(SnackBar(content: Text(s.alerts_testBlocked)));
      return;
    }
    final settings = context.read<SettingsCubit>().state.settingsModel;
    final result = await sl<ScheduleTestAdhan>()(
      ScheduleTestAdhanParams(
        alert: settings.prayerAlerts[PrayerName.dhuhr] ?? const PrayerAlert(),
        localeCode: settings.isArabic ? 'ar' : 'en',
      ),
    );
    final message = result.isRight()
        ? s.alerts_testCaption
        : s.alerts_testBlocked;
    messenger.showSnackBar(SnackBar(content: Text(message)));
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
      label: Text(S.of(context).playTestAdhan, style: TS.semi16),
    );
  }
}
