// lib/features/surah/presentation/pages/surah_list/widgets/juz_browse_list.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/search/domain/entities/juz_browse_entry.dart';
import 'package:quran_app/features/search/domain/services/quran_browse_service.dart';
import 'package:quran_app/generated/l10n.dart';

/// Sliver list of the 30 ajzaʼ; each row jumps to that juzʼ's first page.
Widget juzBrowseSliver(BuildContext context) {
  final entries = sl<QuranBrowseService>().juzEntries();
  return SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
    sliver: SliverList.separated(
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: 8),
      itemBuilder: (_, i) => _JuzTile(entry: entries[i]),
    ),
  );
}

class _JuzTile extends StatelessWidget {
  const _JuzTile({required this.entry});
  final JuzBrowseEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return PrettierTap(
      onTap: () =>
          context.push(AppRouter.mushafPath, extra: entry.firstPage),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(12, 12, 12, 12),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: context.cardBorder(),
          boxShadow: context.cardShadow(),
        ),
        child: Row(
          children: [
            Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.10),
                ),
              ),
              child: Text(
                entry.number.toLocalized(context),
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    S.of(context).juz_label(entry.number.toLocalized(context)),
                    style: TS.bold16.copyWith(color: scheme.onSurface),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${entry.firstSurahArabicName} – ${entry.lastSurahArabicName}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
