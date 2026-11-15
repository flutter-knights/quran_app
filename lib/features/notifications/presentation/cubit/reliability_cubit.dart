import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';
import 'package:quran_app/features/notifications/domain/entities/system_settings_target.dart';
import 'package:quran_app/features/notifications/domain/usecases/ack_missed_alerts.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_reliability_status.dart';
import 'package:quran_app/features/notifications/domain/usecases/open_system_settings.dart';
import 'package:quran_app/features/notifications/presentation/cubit/reliability_state.dart';

class ReliabilityCubit extends Cubit<ReliabilityState> {
  ReliabilityCubit(this._getStatus, this._ackMissed, this._openSettings)
    : super(const ReliabilityLoading()) {
    _lifecycle = AppLifecycleListener(onResume: load);
    load();
  }

  final GetReliabilityStatus _getStatus;
  final AckMissedAlerts _ackMissed;
  final OpenSystemSettings _openSettings;
  late final AppLifecycleListener _lifecycle;

  Future<void> load() async {
    final result = await _getStatus(NoParams());
    if (isClosed) return;
    emit(
      result.fold(
        (_) => const ReliabilityUnavailable(),
        (status) => ReliabilityLoaded(status),
      ),
    );
  }

  Future<void> ackMissed(ReliabilityStatus shown) async {
    final shownAt = [...shown.missed, ...shown.late].map((a) => a.at);
    if (shownAt.isEmpty) return;
    final upTo = shownAt.reduce((a, b) => a.isAfter(b) ? a : b);
    await _ackMissed(AckMissedAlertsParams(upTo: upTo));
    await load();
  }

  Future<void> openSettings(SystemSettingsTarget target) async {
    await _openSettings(target);
  }

  @override
  Future<void> close() {
    _lifecycle.dispose();
    return super.close();
  }
}
