// lib/features/surah/presentation/pages/surah_list/widgets/start_reading_card.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/generated/l10n.dart';

/// Shown in the continue-reading slot before any reading history exists.
class StartReadingCard extends StatelessWidget {
  const StartReadingCard({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      radius: 14,
      onTap: () => context.push(AppRouter.mushafPath, extra: 1),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  S.of(context).start_reading,
                  style: TS.bold14.cairo.copyWith(color: scheme.onSurface),
                ),
                const SizedBox(height: 3),
                Text(
                  S.of(context).start_reading_subtitle,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          HugeIcon(
            icon: forwardArrowIcon(context),
            color: scheme.secondary,
            size: 16,
          ),
        ],
      ),
    );
  }
}
