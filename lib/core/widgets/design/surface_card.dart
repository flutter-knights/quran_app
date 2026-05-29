import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';

/// Surface-toned card with a soft black drop shadow (light mode only).
/// Pass [accentColor] to deepen the shadow (used by the hadith quote block and
/// the narrator card). No borders — shadow only.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.accentColor,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? accentColor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final hasAccent = accentColor != null;
    final card = Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        border: context.cardBorder(),
        boxShadow: context.cardShadow(
          alpha: hasAccent ? 0.15 : 0.08,
          blurRadius: hasAccent ? 18 : 14,
        ),
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return card;
    return PrettierTap(onTap: onTap, child: card);
  }
}
