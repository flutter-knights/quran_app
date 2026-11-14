import 'package:equatable/equatable.dart';

/// A raw heading sample from the device sensor. [heading] is null when the
/// device has no usable magnetometer.
class CompassReading extends Equatable {
  const CompassReading({this.heading, this.accuracy});

  /// Degrees clockwise from north (true on iOS, magnetic on Android), or null.
  final double? heading;

  /// Sensor accuracy in degrees (smaller is better), or null if unknown.
  final double? accuracy;

  bool get hasHeading => heading != null;

  @override
  List<Object?> get props => [heading, accuracy];
}
