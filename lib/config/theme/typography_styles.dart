import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

extension TypographyStylesExtension on TextStyle {
  TextStyle get amiriQuran => GoogleFonts.amiriQuran(textStyle: this);
  TextStyle get cairo => GoogleFonts.cairo(textStyle: this);
  TextStyle get amiri => GoogleFonts.amiri(textStyle: this);
}

typedef TS = TypographyStyles;

abstract class TypographyStyles {
  static TextStyle extra36 = _baseCairo(36, FontWeight.w800, -0.5);
  static TextStyle extra32 = _baseCairo(32, FontWeight.w800, -0.5);
  static TextStyle extra24 = _baseCairo(24, FontWeight.w800);
  static TextStyle extra20 = _baseCairo(20, FontWeight.w800);
  static TextStyle extra16 = _baseCairo(16, FontWeight.w800);

  static TextStyle bold32 = _baseCairo(32, FontWeight.w700, -0.5);
  static TextStyle bold24 = _baseCairo(24, FontWeight.w700);
  static TextStyle bold20 = _baseCairo(20, FontWeight.w700);
  static TextStyle bold16 = _baseCairo(16, FontWeight.w700);
  static TextStyle bold14 = _baseCairo(14, FontWeight.w700);

  static TextStyle semi24 = _baseCairo(24, FontWeight.w600);
  static TextStyle semi20 = _baseCairo(20, FontWeight.w600);
  static TextStyle semi16 = _baseCairo(16, FontWeight.w600);

  static TextStyle medium16 = _baseCairo(16, FontWeight.w500);
  static TextStyle medium14 = _baseCairo(14, FontWeight.w500);

  static TextStyle regular16 = _baseCairo(16, FontWeight.w400);
  static TextStyle regular14 = _baseCairo(14, FontWeight.w400);
  static TextStyle regular12 = _baseCairo(12, FontWeight.w400);

  static TextStyle _baseCairo(
    double size,
    FontWeight weight, [
    double spacing = 0.0,
  ]) {
    return GoogleFonts.cairo(
      textStyle: TextStyle(
        fontSize: size,
        fontWeight: weight,
        letterSpacing: spacing,
      ),
    );
  }
}
