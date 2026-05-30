import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/utils/calculation_method_for_country.dart';

void main() {
  test('maps known countries to their conventional method', () {
    expect(calculationMethodForCountry('Saudi Arabia'), CalculationMethod.ummAlQura);
    expect(calculationMethodForCountry('Egypt'), CalculationMethod.egypt);
    expect(calculationMethodForCountry('Pakistan'), CalculationMethod.karachi);
    expect(calculationMethodForCountry('United States'), CalculationMethod.isna);
    expect(calculationMethodForCountry('Turkey'), CalculationMethod.turkey);
  });

  test('is case/space insensitive', () {
    expect(calculationMethodForCountry('  united states '), CalculationMethod.isna);
  });

  test('falls back to MWL for unknown/null', () {
    expect(calculationMethodForCountry(null), CalculationMethod.mwl);
    expect(calculationMethodForCountry('Atlantis'), CalculationMethod.mwl);
  });
}
