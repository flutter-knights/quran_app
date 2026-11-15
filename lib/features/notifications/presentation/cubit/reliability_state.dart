import 'package:equatable/equatable.dart';
import 'package:quran_app/features/notifications/domain/entities/reliability_status.dart';

sealed class ReliabilityState extends Equatable {
  const ReliabilityState();

  @override
  List<Object?> get props => const [];
}

final class ReliabilityLoading extends ReliabilityState {
  const ReliabilityLoading();
}

final class ReliabilityLoaded extends ReliabilityState {
  final ReliabilityStatus status;

  const ReliabilityLoaded(this.status);

  @override
  List<Object?> get props => [status];
}

final class ReliabilityUnavailable extends ReliabilityState {
  const ReliabilityUnavailable();
}
