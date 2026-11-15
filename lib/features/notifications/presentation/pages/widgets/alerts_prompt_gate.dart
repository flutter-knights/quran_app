import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/notifications/domain/services/alerts_prompt_picker.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_state.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/missed_sheet.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/upgrade_sheet.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class AlertsPromptGate extends StatefulWidget {
  const AlertsPromptGate({super.key, required this.child});

  final Widget child;

  @override
  State<AlertsPromptGate> createState() => _AlertsPromptGateState();
}

class _AlertsPromptGateState extends State<AlertsPromptGate> {
  bool _shown = false;

  void _onStatus(BuildContext context, ReliabilityState state) {
    if (_shown || state is! ReliabilityLoaded) return;
    final settings = context.read<SettingsCubit>();
    final model = settings.state.settingsModel;
    final status = state.status;
    final pick = pickAlertsPrompt(
      alertsIntroSeen: model.alertsIntroSeen,
      onboardingComplete: model.hasCompletedOnboarding,
      status: status,
    );
    if (pick == null) return;
    _shown = true;
    switch (pick) {
      case (prompt: AlertsPrompt.upgrade, prayer: _):
        UpgradeSheet.show(context, isXiaomi: status.isXiaomi);
        settings.markAlertsIntroSeen();
      case (:final prompt, prayer: final prayer?):
        MissedSheet.show(
          context,
          kind: prompt,
          prayer: prayer,
          isXiaomi: status.isXiaomi,
        );
        context.read<ReliabilityCubit>().ackMissed(status);
        if (status.isXiaomi) settings.clearXiaomiConfirmations();
      case _:
        return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ReliabilityCubit>(),
      child: BlocListener<ReliabilityCubit, ReliabilityState>(
        listenWhen: (p, c) =>
            p is ReliabilityLoading && c is! ReliabilityLoading,
        listener: _onStatus,
        child: widget.child,
      ),
    );
  }
}
