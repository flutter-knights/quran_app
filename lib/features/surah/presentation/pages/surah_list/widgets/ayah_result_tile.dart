// lib/features/surah/presentation/pages/surah_list/widgets/ayah_result_tile.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/search/domain/entities/search_result.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_args.dart';
import 'package:quran_app/generated/l10n.dart';

class AyahResultTile extends StatelessWidget {
  const AyahResultTile({super.key, required this.result});
  final AyahResult result;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final meta = [
      result.surahArabicName,
      S.of(context).ayah_label(
            result.surah.toLocalized(context),
            result.ayah.toLocalized(context),
          ),
      S.of(context).page_label(result.page.toLocalized(context)),
    ].join(' · ');

    return PrettierTap(
      onTap: () => context.push(
        AppRouter.mushafPath,
        extra: MushafArgs(
          page: result.page,
          focusAyah:
              AyahIdentifier(surah: result.surah, ayah: result.ayah),
        ),
      ),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 10, 12, 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: context.cardBorder(),
          boxShadow: context.cardShadow(),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              result.text,
              textAlign: TextAlign.right,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: TS.bold16.scheherazade.copyWith(
                color: scheme.onSurface,
                height: 1.8,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              meta,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
