import 'package:equatable/equatable.dart';
import 'package:geomag/geomag.dart';
import 'package:intl/intl.dart';
import 'package:quran_app/core/usecases/usecase.dart';

class DeclinationParams extends Equatable {
  const DeclinationParams({
    required this.latitude,
    required this.longitude,
    required this.date,
  });

  final double latitude;
  final double longitude;
  final DateTime date;

  @override
  List<Object?> get props => [latitude, longitude, date];
}

/// Magnetic declination (degrees east of true north) at a location, from the
/// World Magnetic Model via the `geomag` package. Pure computation.
class GetMagneticDeclination implements UseCase<double, DeclinationParams> {
  // `geomag`'s WmmCof parses its model date with a locale-less
  // `DateFormat('MM/dd/yyyy')`, which throws a FormatException when built while
  // a non-Latin-digit locale (e.g. Arabic) is active — the app runs under 'ar',
  // so constructing GeoMag() directly crashed QiblaCubit on the /qibla route.
  // Pin construction to a fixed Latin locale so the date parse always succeeds.
  GetMagneticDeclination({GeoMag? geoMag})
      : _geoMag = geoMag ?? Intl.withLocale('en_US', () => GeoMag());

  final GeoMag _geoMag;

  @override
  Future<double> call(DeclinationParams params) async {
    final result = _geoMag.calculate(
      params.latitude,
      params.longitude,
      0, // altitude in feet
      params.date,
    );
    return result.dec;
  }
}
