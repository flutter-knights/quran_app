import 'package:flutter/material.dart';

extension TypographyStylesExtension on TextStyle {
  TextStyle get uthmanic {
    return copyWith(fontFamily: TypographyStyles.uthmanic);
  }

  TextStyle get cairo {
    return copyWith(fontFamily: TypographyStyles.cairo);
  }
}

abstract class TypographyStyles {
  static const String uthmanic = "uthmanic";
  static const String cairo = "cairo";

  // Display (Large headers)
  static const TextStyle display32 = TextStyle(
    fontSize: 32,
    fontWeight: FontWeight.w600,
    letterSpacing: -0.5,
  );

  // Page Title
  static const TextStyle title24 = TextStyle(
    fontSize: 24,
    fontWeight: FontWeight.w600,
  );

  // Headings
  static const TextStyle heading20 = TextStyle(
    fontSize: 20,
    fontWeight: FontWeight.w600,
  );

  // Body text
  static const TextStyle body16 = TextStyle(
    fontSize: 16,
    fontWeight: FontWeight.w500,
  );

  static const TextStyle body14 = TextStyle(
    fontSize: 14,
    fontWeight: FontWeight.w400,
  );

  // Caption / Small text
  static const TextStyle caption12 = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );

  static const TextStyle caption10 = TextStyle(
    fontSize: 10,
    fontWeight: FontWeight.w400,
    letterSpacing: 0.2,
  );
}

extension LocalizationExtensions on BuildContext {
  bool isArabic() => Localizations.localeOf(this).languageCode == 'ar';
}
