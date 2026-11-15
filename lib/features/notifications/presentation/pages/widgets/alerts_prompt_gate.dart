import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/services/alerts_prompt_picker.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_cubit.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_state.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/missed_sheet.dart';
import 'package:quran_app/features/notifications/presentation/pages/widgets/upgrade_sheet.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

class AlertsPromptGate extends StatelessWidget {
  const AlertsPromptGate({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => sl<ReliabilityCubit>(),
      child: _PromptListener(child: child),
    );
  }
}

class _PromptListener extends StatefulWidget {
  const _PromptListener({required this.child});

  final Widget child;

  @override
  State<_PromptListener> createState() => _PromptListenerState();
}

class _PromptListenerState extends State<_PromptListener> {
  bool _open = false;
  bool _pending = false;
  bool _wasCurrent = false;
  DateTime? _shownUpTo;

  bool get _isCurrent => ModalRoute.of(context)?.isCurrent ?? true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final current = _isCurrent;
    if (current && !_wasCurrent && _pending) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final state = context.read<ReliabilityCubit>().state;
        if (state is ReliabilityLoaded) _evaluate(state.status);
      });
    }
    _wasCurrent = current;
  }

  Future<void> _evaluate(ReliabilityStatus status) async {
    if (_open || !_isCurrent) {
      _pending = true;
      return;
    }
    _pending = false;
    final settings = context.read<SettingsCubit>();
    final model = settings.state.settingsModel;
    final pick = pickAlertsPrompt(
      alertsIntroSeen: model.alertsIntroSeen,
      onboardingComplete: model.hasCompletedOnboarding,
      status: status,
    );
    switch (pick) {
      case null:
        return;
      case (prompt: AlertsPrompt.upgrade, prayer: _):
        settings.markAlertsIntroSeen();
        await _show(UpgradeSheet.show(context, isXiaomi: status.isXiaomi));
      case (:final prompt, :final prayer?):
        final newest = [
          ...status.missed,
          ...status.late,
        ].map((a) => a.at).reduce((a, b) => a.isAfter(b) ? a : b);
        final shownUpTo = _shownUpTo;
        if (shownUpTo != null && !newest.isAfter(shownUpTo)) return;
        _shownUpTo = newest;
        final sheet = MissedSheet.show(
          context,
          kind: prompt,
          prayer: prayer,
          isXiaomi: status.isXiaomi,
        );
        context.read<ReliabilityCubit>().ackMissed(status);
        if (status.isXiaomi) settings.clearXiaomiConfirmations();
        await _show(sheet);
      case _:
        return;
    }
  }

  Future<void> _show(Future<void> sheet) async {
    _open = true;
    await sheet;
    if (mounted) _open = false;
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<ReliabilityCubit, ReliabilityState>(
      listenWhen: (p, c) => c is ReliabilityLoaded && p != c,
      listener: (context, state) =>
          _evaluate((state as ReliabilityLoaded).status),
      child: widget.child,
    );
  }
}
