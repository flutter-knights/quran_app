part of 'qibla_cubit.dart';

abstract class QiblaState extends Equatable {
  const QiblaState();
  @override
  List<Object?> get props => [];
}

class QiblaInitial extends QiblaState {
  const QiblaInitial();
}

class QiblaLoading extends QiblaState {
  const QiblaLoading();
}

class QiblaError extends QiblaState {
  const QiblaError(this.failure);
  final Failure failure;
  @override
  List<Object?> get props => [failure];
}

class QiblaLoaded extends QiblaState {
  const QiblaLoaded({
    required this.direction,
    required this.locationName,
    required this.hasCompass,
    this.trueHeading,
    this.accuracy,
  });

  final QiblaDirection direction;
  final String? locationName;

  /// false => no magnetometer; UI shows the numeric fallback.
  final bool hasCompass;

  /// Device heading already converted to TRUE north; null until first reading.
  final double? trueHeading;
  final double? accuracy;

  double? get pointerAngle => trueHeading == null
      ? null
      : QiblaCalculator.pointerAngle(direction.bearing, trueHeading!);

  bool get isAligned =>
      pointerAngle != null && QiblaCalculator.isAligned(pointerAngle!);

  /// Low-accuracy => prompt calibration (figure-8). >15 deg is unreliable.
  bool get needsCalibration => accuracy != null && accuracy! > 15;

  QiblaLoaded copyWith({double? trueHeading, double? accuracy, bool? hasCompass}) {
    return QiblaLoaded(
      direction: direction,
      locationName: locationName,
      hasCompass: hasCompass ?? this.hasCompass,
      trueHeading: trueHeading ?? this.trueHeading,
      accuracy: accuracy ?? this.accuracy,
    );
  }

  @override
  List<Object?> get props =>
      [direction, locationName, hasCompass, trueHeading, accuracy];
}
