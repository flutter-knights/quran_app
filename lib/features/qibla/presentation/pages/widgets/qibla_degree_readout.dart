import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_rose.dart';
import 'package:quran_app/features/qibla/presentation/utils/compass_rose_localization.dart';
import 'package:quran_app/generated/l10n.dart';

class QiblaDegreeReadout extends StatelessWidget {
  const QiblaDegreeReadout({
    super.key,
    required this.bearing,
    required this.rose,
  });

  final double bearing;
  final CompassRose rose;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final deg = localizeDigits(context, bearing.round());
    return Column(
      children: [
        Text(
          '$deg°',
          style: TS.bold16.copyWith(
            fontSize: 40,
            height: 1,
            color: scheme.onSurface,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          '${rose.localized(context)} · ${S.of(context).qibla_bearing_suffix}',
          style: TS.regular14.copyWith(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
