import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/notifications/prayer_notification_scheduler.dart';
import 'package:quran_app/features/notifications/data/datasources/notifications_native_data_source.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

/// Production-visible "Play test adhan" button. Fires the same native test
/// path as the prior debug FAB.
class TestAdhanButton extends StatelessWidget {
  const TestAdhanButton({super.key});

  Future<void> _onPressed(BuildContext context) async {
    final isAndroid = defaultTargetPlatform == TargetPlatform.android;
    final localeCode =
        context.read<SettingsCubit>().state.settingsModel.isArabic ? 'ar' : 'en';
    if (isAndroid) {
      await sl<NotificationsNativeDataSource>().scheduleTestAdhan(
        delay: const Duration(seconds: 5),
        localeCode: localeCode,
      );
    } else {
      await sl<PrayerNotificationScheduler>().scheduleTestNotification(
        delay: const Duration(seconds: 5),
      );
    }
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).testAdhanScheduledSnack)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: context.colorScheme.surfaceContainer,
      borderRadius: BorderRadius.circular(14),
      child: InkWell(
        onTap: () => _onPressed(context),
        borderRadius: BorderRadius.circular(14),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              HugeIcon(
                icon: HugeIcons.strokeRoundedPlayCircle,
                color: context.colorScheme.primary,
                size: 22,
              ),
              const SizedBox(width: 12),
              Text(
                S.of(context).playTestAdhan,
                style: TS.bold16.cairo.copyWith(
                  color: context.colorScheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
