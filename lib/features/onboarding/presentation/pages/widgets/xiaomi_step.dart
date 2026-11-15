import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/xiaomi_checklist.dart';
import 'package:quran_app/features/onboarding/presentation/pages/widgets/onboarding_step_header.dart';

class XiaomiStep extends StatelessWidget {
  const XiaomiStep({super.key});

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final theme = Theme.of(context);
    final onBackdrop = theme.copyWith(
      colorScheme: theme.colorScheme.copyWith(
        brightness: Brightness.dark,
        primary: Colors.white,
        onSurface: Colors.white,
        onSurfaceVariant: Colors.white.withValues(alpha: 0.75),
        surfaceContainer: Colors.white.withValues(alpha: 0.08),
      ),
    );
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 8, 22, 8),
      child: Column(
        spacing: 20,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingStepHeader(
            icon: HugeIcons.strokeRoundedBatteryCharging01,
            title: s.onb_xiaomi_title,
            lead: s.onb_xiaomi_lead,
          ),
          Theme(
            data: onBackdrop,
            child: const XiaomiChecklist(ink: Colors.white),
          ),
        ],
      ),
    );
  }
}
