import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';

void main() {
  test('defaults: method auto, school shafi', () {
    const s = SettingsModel(isFormat12Hours: false, isArabic: true);
    expect(s.calculationMethod, CalculationMethod.auto);
    expect(s.asrSchool, AsrSchool.shafi);
  });

  test('round-trips through toMap/fromMap', () {
    const s = SettingsModel(
      isFormat12Hours: false,
      isArabic: true,
      calculationMethod: CalculationMethod.egypt,
      asrSchool: AsrSchool.hanafi,
    );
    final back = SettingsModel.fromMap(s.toMap());
    expect(back.calculationMethod, CalculationMethod.egypt);
    expect(back.asrSchool, AsrSchool.hanafi);
  });

  test('unknown persisted values fall back to defaults', () {
    final back = SettingsModel.fromMap({
      'isArabic': true,
      'calculationMethod': 'bogus',
      'asrSchool': 'bogus',
    });
    expect(back.calculationMethod, CalculationMethod.auto);
    expect(back.asrSchool, AsrSchool.shafi);
  });
}
