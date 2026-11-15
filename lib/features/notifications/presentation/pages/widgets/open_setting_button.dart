import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/notifications/domain/entities/system_settings_target.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';

class OpenSettingButton extends StatelessWidget {
  const OpenSettingButton({super.key, required this.target, required this.ink});

  final SystemSettingsTarget target;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(0, 48),
        foregroundColor: ink,
        side: BorderSide(color: ink.withValues(alpha: 0.5)),
      ),
      onPressed: () => context.read<ReliabilityCubit>().openSettings(target),
      child: Text(PendingS.of(context).rel_openSettings, style: TS.semi14),
    );
  }
}
