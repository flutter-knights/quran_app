import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

/// Row of equal-flex 44h buttons. Use `ActionBtn.primary` for the filled
/// emphasis variant.
class ActionButtonsRow extends StatelessWidget {
  const ActionButtonsRow({super.key, required this.children});
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (var i = 0; i < children.length; i++) ...[
          if (i > 0) const SizedBox(width: 10),
          Expanded(child: children[i]),
        ],
      ],
    );
  }
}

class ActionBtn extends StatelessWidget {
  const ActionBtn({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.iconTrailing = false,
  }) : _primary = false;

  const ActionBtn.primary({
    super.key,
    required this.icon,
    required this.label,
    this.onPressed,
    this.iconTrailing = false,
  }) : _primary = true;

  final Widget icon;
  final String label;
  final VoidCallback? onPressed;

  /// Renders the icon after the label. Combined with a directional arrow this
  /// keeps a "forward" action's arrow trailing — right in LTR, left in RTL.
  final bool iconTrailing;
  final bool _primary;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final fg = _primary ? Colors.white : scheme.onSurfaceVariant;
    final bg = _primary
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.06);
    final border = _primary
        ? scheme.primary
        : scheme.onSurface.withValues(alpha: 0.12);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onPressed,
        child: Container(
          height: 44,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: border),
          ),
          padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (final w in iconTrailing
                  ? [_label(fg), const SizedBox(width: 6), _icon(fg)]
                  : [_icon(fg), const SizedBox(width: 6), _label(fg)])
                w,
            ],
          ),
        ),
      ),
    );
  }

  Widget _icon(Color fg) =>
      IconTheme(data: IconThemeData(color: fg, size: 14), child: icon);

  Widget _label(Color fg) => Text(
        label,
        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: fg),
      );
}
