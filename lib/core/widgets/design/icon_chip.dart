import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';

/// 38×38 rounded-10 button used in app bars. Matches the HTML `.icon-btn`.
class IconChip extends StatelessWidget {
  const IconChip({
    super.key,
    required this.icon,
    this.onPressed,
    this.size = 38,
    this.iconSize = 16,
  });

  final Widget icon;
  final VoidCallback? onPressed;
  final double size;
  final double iconSize;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return PrettierTap(
      onTap: onPressed,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: scheme.onSurface.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.onSurface.withValues(alpha: 0.12)),
        ),
        alignment: Alignment.center,
        child: IconTheme(
          data: IconThemeData(color: scheme.onSurface, size: iconSize),
          child: icon,
        ),
      ),
    );
  }
}
