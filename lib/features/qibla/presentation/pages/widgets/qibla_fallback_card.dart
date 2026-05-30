import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/qibla/presentation/utils/compass_rose_localization.dart';
import 'package:quran_app/generated/l10n.dart';

class QiblaFallbackCard extends StatelessWidget {
  const QiblaFallbackCard({super.key, required this.bearing});
  final double bearing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final s = S.of(context);
    final deg = localizeDigits(context, bearing.round());
    return SurfaceCard(
      child: Column(
        children: [
          HugeIcon(icon: HugeIcons.strokeRoundedCompass, color: scheme.primary, size: 30),
          const SizedBox(height: 12),
          Text(s.qibla_no_compass_title,
              textAlign: TextAlign.center, style: TS.bold16.copyWith(color: scheme.onSurface)),
          const SizedBox(height: 8),
          Text(s.qibla_align_manually(deg),
              textAlign: TextAlign.center,
              style: TS.regular14.copyWith(color: scheme.onSurface.withValues(alpha: 0.7))),
        ],
      ),
    );
  }
}
