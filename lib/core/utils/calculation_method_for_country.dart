import 'package:quran_app/core/constants/calculation_method.dart';

/// Picks the conventional calculation method for a country (English name from
/// reverse geocoding). Returns [CalculationMethod.mwl] when unknown/null.
CalculationMethod calculationMethodForCountry(String? enCountry) {
  if (enCountry == null) return CalculationMethod.mwl;
  final key = enCountry.trim().toLowerCase();
  return _byCountry[key] ?? CalculationMethod.mwl;
}

const Map<String, CalculationMethod> _byCountry = {
  'saudi arabia': CalculationMethod.ummAlQura,
  'egypt': CalculationMethod.egypt,
  'pakistan': CalculationMethod.karachi,
  'india': CalculationMethod.karachi,
  'bangladesh': CalculationMethod.karachi,
  'afghanistan': CalculationMethod.karachi,
  'united states': CalculationMethod.isna,
  'canada': CalculationMethod.isna,
  'turkey': CalculationMethod.turkey,
  'türkiye': CalculationMethod.turkey,
  'kuwait': CalculationMethod.kuwait,
  'qatar': CalculationMethod.qatar,
  'singapore': CalculationMethod.singapore,
  'france': CalculationMethod.france,
  'russia': CalculationMethod.russia,
  'iran': CalculationMethod.tehran,
  'united arab emirates': CalculationMethod.gulf,
  'bahrain': CalculationMethod.gulf,
  'oman': CalculationMethod.gulf,
  'yemen': CalculationMethod.gulf,
};
