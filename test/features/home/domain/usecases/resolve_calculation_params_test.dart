import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/features/home/domain/usecases/resolve_calculation_params.dart';

void main() {
  test('auto resolves via country', () {
    final p = resolveCalculationParams(
        method: CalculationMethod.auto, school: AsrSchool.shafi, enCountry: 'Egypt');
    expect(p.method, 5);
    expect(p.school, 0);
  });
  test('explicit method wins over country', () {
    final p = resolveCalculationParams(
        method: CalculationMethod.karachi, school: AsrSchool.hanafi, enCountry: 'Egypt');
    expect(p.method, 1);
    expect(p.school, 1);
  });
  test('auto + unknown country falls back to MWL', () {
    final p = resolveCalculationParams(
        method: CalculationMethod.auto, school: AsrSchool.shafi, enCountry: null);
    expect(p.method, 3);
  });
}
