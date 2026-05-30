import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:intl/intl.dart';
import 'package:quran_app/features/qibla/domain/usecases/get_magnetic_declination.dart';

/// Regression: the app runs under the Arabic locale. `geomag`'s `GeoMag()`
/// constructor parses its WMM model date with a locale-less `DateFormat`,
/// which throws a FormatException when constructed while the Arabic locale is
/// active (Arabic-Indic digits) — this crashed QiblaCubit creation on /qibla.
/// `GetMagneticDeclination` must construct geomag under a fixed Latin locale
/// regardless of the ambient locale.
void main() {
  test('constructs geomag under an active Arabic locale without crashing',
      () async {
    await initializeDateFormatting('ar', null);

    // Mirrors the running app: the Arabic locale is the *current* Intl locale
    // at the moment QiblaCubit (and thus GetMagneticDeclination) is built.
    final usecase = Intl.withLocale('ar', () => GetMagneticDeclination());

    final dec = await usecase(DeclinationParams(
      latitude: 21.4225,
      longitude: 39.8262,
      date: DateTime(2024, 1, 1),
    ));
    expect(dec, inInclusiveRange(-45.0, 45.0));
  });
}
