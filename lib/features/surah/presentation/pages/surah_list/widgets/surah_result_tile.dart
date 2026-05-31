// lib/features/surah/presentation/pages/surah_list/widgets/surah_result_tile.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/search/domain/entities/search_result.dart';

class SurahResultTile extends StatelessWidget {
  const SurahResultTile({super.key, required this.result});
  final SurahResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return PrettierTap(
      onTap: () =>
          context.push(AppRouter.mushafPath, extra: result.page),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: context.cardBorder(),
          boxShadow: context.cardShadow(),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    result.arabicName,
                    style: TS.bold16.copyWith(color: scheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    result.englishName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              width: 30,
              height: 30,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.10),
                ),
              ),
              child: Text(
                result.number.toLocalized(context),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
