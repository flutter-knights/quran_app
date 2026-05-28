import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';

/// Compact card with uppercase label (in [accentColor]) over body text.
/// Used for the Narrator card and any future "labelled note" surface.
class LabelledAccentCard extends StatelessWidget {
  const LabelledAccentCard({
    super.key,
    required this.label,
    required this.body,
    required this.accentColor,
  });

  final String label;
  final String body;
  final Color accentColor;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.all(14),
      radius: 12,
      accentColor: accentColor,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: accentColor,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 5),
          Text(
            body,
            style: TS.regular14.copyWith(
              color: scheme.onSurfaceVariant,
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}
