import 'package:flutter/material.dart';

extension ColorSchemeExtension on BuildContext {
  ColorScheme get colorScheme => Theme.of(this).colorScheme;

  /// Soft elevation shadow for cards. Empty in dark mode — cards already read as
  /// raised via the lighter `surfaceContainer`. Light mode uses a neutral black
  /// shadow; an accent-tinted one reads as a coloured blur, not a drop shadow.
  List<BoxShadow> cardShadow({double alpha = 0.08, double blurRadius = 14}) {
    if (Theme.of(this).brightness == Brightness.dark) return const [];
    return [
      BoxShadow(
        color: Colors.black.withValues(alpha: alpha),
        blurRadius: blurRadius,
        offset: const Offset(0, 5),
      ),
    ];
  }

  /// Very dim accent outline that lifts a card off the background and away from
  /// its own shadow. Applied in both light and dark modes.
  Border cardBorder({double alpha = 0.10}) {
    return Border.all(color: colorScheme.primary.withValues(alpha: alpha));
  }
}
