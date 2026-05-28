import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

/// Surface-toned card with a 1px border and an optional accent on the
/// **leading** edge (left in LTR, right in RTL). Replaces the HTML mockup's
/// hard-coded `border-right` / `border-left` rules.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 16,
    this.leadingAccentColor,
    this.accentWidth = 3,
    this.onTap,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color? leadingAccentColor;
  final double accentWidth;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final border = leadingAccentColor != null
        ? BorderDirectional(
            top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            bottom: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            end: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.4)),
            start: BorderSide(color: leadingAccentColor!, width: accentWidth),
          )
        : Border.all(color: scheme.outlineVariant.withValues(alpha: 0.4));
    final card = Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(radius),
        border: border is Border ? border : null,
      ),
      foregroundDecoration: border is BorderDirectional
          ? BoxDecoration(
              border: border,
              borderRadius: BorderRadius.circular(radius),
            )
          : null,
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
