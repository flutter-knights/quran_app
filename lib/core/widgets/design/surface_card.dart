import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

/// Surface-toned card with a soft drop shadow tinted by the theme accent.
/// Pass [accentColor] to tint the shadow more strongly (used by the hadith
/// quote block and the narrator card). No borders — shadow only.
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
    final tint = accentColor ?? scheme.primary;
    final card = Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: tint.withValues(alpha: hasAccent ? 0.22 : 0.12),
            blurRadius: hasAccent ? 18 : 14,
            offset: const Offset(0, 5),
          ),
        ],
      ),
      padding: padding,
      child: child,
    );
    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(radius),
      child: InkWell(
        borderRadius: BorderRadius.circular(radius),
        onTap: onTap,
        child: card,
      ),
    );
  }
}
