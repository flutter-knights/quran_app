import 'package:flutter/widgets.dart';
import 'package:quran_app/core/constants/calculation_method.dart';
import 'package:quran_app/generated/l10n.dart';

extension CalculationMethodL10n on CalculationMethod {
  String localized(BuildContext context) {
    final s = S.of(context);
    switch (this) {
      case CalculationMethod.auto:
        return s.calculationMethod_auto;
      case CalculationMethod.mwl:
        return s.calculationMethod_mwl;
      case CalculationMethod.isna:
        return s.calculationMethod_isna;
      case CalculationMethod.egypt:
        return s.calculationMethod_egypt;
      case CalculationMethod.ummAlQura:
        return s.calculationMethod_ummAlQura;
      case CalculationMethod.karachi:
        return s.calculationMethod_karachi;
      case CalculationMethod.tehran:
        return s.calculationMethod_tehran;
      case CalculationMethod.gulf:
        return s.calculationMethod_gulf;
      case CalculationMethod.kuwait:
        return s.calculationMethod_kuwait;
      case CalculationMethod.qatar:
        return s.calculationMethod_qatar;
      case CalculationMethod.singapore:
        return s.calculationMethod_singapore;
      case CalculationMethod.france:
        return s.calculationMethod_france;
      case CalculationMethod.turkey:
        return s.calculationMethod_turkey;
      case CalculationMethod.russia:
        return s.calculationMethod_russia;
    }
  }
}

extension AsrSchoolL10n on AsrSchool {
  String localized(BuildContext context) {
    final s = S.of(context);
    switch (this) {
      case AsrSchool.shafi:
        return s.asrSchool_shafi;
      case AsrSchool.hanafi:
        return s.asrSchool_hanafi;
    }
  }
}
