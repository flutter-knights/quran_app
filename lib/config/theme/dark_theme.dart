import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

import 'typography_styles.dart';

final ThemeData darkTheme = ThemeData(
  useMaterial3: true,
  colorScheme: darkColorScheme,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: darkColorScheme.surfaceContainer,
    suffixIconColor: darkColorScheme.onSurface,
    prefixIconColor: darkColorScheme.onSurface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    hintStyle: TS.regular15.copyWith(color: darkColorScheme.onSurface),
    contentPadding: const EdgeInsets.symmetric(vertical: 12),
  ),
);
