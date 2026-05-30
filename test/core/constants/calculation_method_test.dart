import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/calculation_method.dart';

void main() {
  test('CalculationMethod carries Aladhan integer ids', () {
    expect(CalculationMethod.mwl.aladhanId, 3);
    expect(CalculationMethod.isna.aladhanId, 2);
    expect(CalculationMethod.ummAlQura.aladhanId, 4);
    expect(CalculationMethod.egypt.aladhanId, 5);
    expect(CalculationMethod.karachi.aladhanId, 1);
    // `auto` has no concrete id and must be resolved before hitting the API.
    expect(CalculationMethod.auto.aladhanId, isNull);
  });

  test('AsrSchool carries Aladhan school ids', () {
    expect(AsrSchool.shafi.aladhanId, 0);
    expect(AsrSchool.hanafi.aladhanId, 1);
  });
}
