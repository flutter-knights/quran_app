import 'package:flutter/material.dart';

extension TypographyStylesExtension on TextStyle {
  TextStyle get cairo => copyWith(fontFamily: TS.fontFamily);
  TextStyle get amiri => copyWith(fontFamily: 'Amiri');
  TextStyle get scheherazade => copyWith(fontFamily: 'ScheherazadeNew');
}

typedef TS = TypographyStyles;

abstract final class TypographyStyles {
  static const String fontFamily = 'Cairo';

  static final TextStyle extra36 = _base(36, FontWeight.w800, -0.5);
  static final TextStyle extra32 = _base(32, FontWeight.w800, -0.5);
  static final TextStyle extra24 = _base(24, FontWeight.w800);
  static final TextStyle extra20 = _base(20, FontWeight.w800);
  static final TextStyle extra16 = _base(16, FontWeight.w800);

  static final TextStyle bold32 = _base(32, FontWeight.w700, -0.5);
  static final TextStyle bold24 = _base(24, FontWeight.w700);
  static final TextStyle bold20 = _base(20, FontWeight.w700);
  static final TextStyle bold16 = _base(16, FontWeight.w700);
  static final TextStyle bold14 = _base(14, FontWeight.w700);
  static final TextStyle bold12 = _base(12, FontWeight.w700);

  static final TextStyle semi32 = _base(32, FontWeight.w600);
  static final TextStyle semi28 = _base(28, FontWeight.w600);
  static final TextStyle semi26 = _base(26, FontWeight.w600);
  static final TextStyle semi24 = _base(24, FontWeight.w600);
  static final TextStyle semi20 = _base(20, FontWeight.w600);
  static final TextStyle semi16 = _base(16, FontWeight.w600);
  static final TextStyle semi14 = _base(14, FontWeight.w600);
  static final TextStyle semi12 = _base(12, FontWeight.w600);

  static final TextStyle medium32 = _base(32, FontWeight.w500);
  static final TextStyle medium16 = _base(16, FontWeight.w500);
  static final TextStyle medium14 = _base(14, FontWeight.w500);
  static final TextStyle medium12 = _base(12, FontWeight.w500);

  static final TextStyle regular16 = _base(16, FontWeight.w400);
  static final TextStyle regular15 = _base(15, FontWeight.w400);
  static final TextStyle regular14 = _base(14, FontWeight.w400);
  static final TextStyle regular12 = _base(12, FontWeight.w400);
  static final TextStyle regular10 = _base(10, FontWeight.w400);
  static final TextStyle regular9 = _base(9, FontWeight.w400);

  static TextStyle _base(
    double size,
    FontWeight weight, [
    double spacing = 0.0,
  ]) {
    return TextStyle(
      fontFamily: fontFamily,
      fontSize: size,
      fontWeight: weight,
      letterSpacing: spacing,
    );
  }
}
