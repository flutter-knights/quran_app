import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';

/// `[10sp uppercase label]` over `[15sp Amiri title]`, vertically centred.
class AppBarCenterTitle extends StatelessWidget {
  const AppBarCenterTitle({super.key, this.label, required this.title});

  final String? label;
  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (label != null)
          Text(
            label!.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w500,
              color: scheme.onSurfaceVariant,
              letterSpacing: 0.5,
            ),
          ),
        Text(
          title,
          style: TS.bold16.amiri.copyWith(
            fontSize: 15,
            color: scheme.onSurface,
          ),
        ),
      ],
    );
  }
}
