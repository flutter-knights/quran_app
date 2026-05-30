import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/generated/l10n.dart';

class QiblaStatusPill extends StatelessWidget {
  const QiblaStatusPill({
    super.key,
    required this.isAligned,
    required this.needsCalibration,
  });

  final bool isAligned;
  final bool needsCalibration;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final s = S.of(context);
    final aligned = isAligned && !needsCalibration;
    final color = aligned ? const Color(0xFF3D9E6E) : scheme.onSurfaceVariant;
    final label = needsCalibration
        ? s.qibla_calibrate_hint
        : aligned
            ? s.qibla_aligned
            : s.qibla_point_to_kaaba;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: aligned ? const Color(0x1F3D9E6E) : scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: context.cardBorder(),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(color: color, shape: BoxShape.circle),
          ),
          const SizedBox(width: 7),
          Text(label, style: TS.bold14.copyWith(color: color)),
        ],
      ),
    );
  }
}
