import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

/// `——— ◆ ———` — a thin line, 6×6 rotated diamond in secondary, line.
class OrnamentDivider extends StatelessWidget {
  const OrnamentDivider({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final line = Expanded(
      child: Container(
        height: 1,
        color: scheme.outlineVariant.withValues(alpha: 0.4),
      ),
    );
    return Row(
      children: [
        line,
        const SizedBox(width: 10),
        Transform.rotate(
          angle: 0.785398, // pi/4
          child: Container(
            width: 6,
            height: 6,
            decoration: BoxDecoration(
              color: scheme.secondary,
              borderRadius: BorderRadius.circular(1),
            ),
          ),
        ),
        const SizedBox(width: 10),
        line,
      ],
    );
  }
}
