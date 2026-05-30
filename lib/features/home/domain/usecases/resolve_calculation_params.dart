import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/core/utils/calculation_method_for_country.dart';

class ResolvedCalculationParams {
  const ResolvedCalculationParams(this.method, this.school);
  final int method;
  final int school;
}

ResolvedCalculationParams resolveCalculationParams({
  required CalculationMethod method,
  required AsrSchool school,
  required String? enCountry,
}) {
  final resolved = method == CalculationMethod.auto
      ? calculationMethodForCountry(enCountry)
      : method;
  return ResolvedCalculationParams(resolved.aladhanId!, school.aladhanId);
}
