import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

import 'typography_styles.dart';

final ThemeData lightTheme = ThemeData(
  useMaterial3: true,
  colorScheme: lightColorScheme,
  inputDecorationTheme: InputDecorationTheme(
    filled: true,
    fillColor: lightColorScheme.surfaceContainer,
    prefixIconColor: lightColorScheme.onSurface,
    suffixIconColor: lightColorScheme.onSurface,

    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(8),
      borderSide: BorderSide.none,
    ),
    hintStyle: TS.regular15.copyWith(color: darkColorScheme.onSurfaceVariant),
    contentPadding: const EdgeInsets.symmetric(vertical: 12),
  ),
);
