import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/qibla/domain/entities/qibla_direction.dart';
import 'package:quran_app/features/qibla/domain/utils/qibla_calculator.dart';

/// Pure computation: turns a [Location] into the Qibla bearing + distance.
/// Cannot fail, so it returns the value directly (no Either).
class GetQiblaDirection implements UseCase<QiblaDirection, Location> {
  @override
  Future<QiblaDirection> call(Location params) async {
    final bearing =
        QiblaCalculator.bearingToKaaba(params.latitude, params.longitude);
    final distance =
        QiblaCalculator.distanceToKaabaKm(params.latitude, params.longitude);
    return QiblaDirection(
      bearing: bearing,
      distanceKm: distance,
      rose: QiblaCalculator.roseFor(bearing),
    );
  }
}
