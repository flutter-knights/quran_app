import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/qibla/presentation/utils/compass_rose_localization.dart';
import 'package:quran_app/generated/l10n.dart';

class QiblaMetaCards extends StatelessWidget {
  const QiblaMetaCards({
    super.key,
    required this.locationName,
    required this.distanceKm,
  });

  final String? locationName;
  final double distanceKm;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Row(
      children: [
        Expanded(
          child: _MetaCard(
            icon: HugeIcons.strokeRoundedLocation01,
            value: locationName ?? '—',
            label: s.qibla_your_location,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: _MetaCard(
            icon: HugeIcons.strokeRoundedGlobe02,
            value: s.qibla_distance_km(
              localizeDigits(context, distanceKm.round()),
            ),
            label: s.qibla_to_makkah,
          ),
        ),
      ],
    );
  }
}

class _MetaCard extends StatelessWidget {
  const _MetaCard({
    required this.icon,
    required this.value,
    required this.label,
  });

  final List<List<dynamic>> icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          HugeIcon(icon: icon, size: 18, color: scheme.secondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TS.bold14.copyWith(color: scheme.onSurface),
                ),
                Text(
                  label,
                  style: TS.regular12.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
