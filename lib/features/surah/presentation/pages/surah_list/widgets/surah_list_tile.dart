import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/surah/domain/entities/surah_entity.dart';
import 'package:quran_app/generated/l10n.dart';

class SurahListTile extends StatelessWidget {
  final SurahEntity surah;

  const SurahListTile({super.key, required this.surah});

  String _ayahLabel(int count) => count > 10 ? "آية" : "آيات";

  void _openMushaf(BuildContext context) =>
      context.push(AppRouter.mushafPath, extra: surah.pageNumber);

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final meta = [
      surah.revelationType,
      "${surah.numberOfAyahs.toLocalized(context)} ${_ayahLabel(surah.numberOfAyahs)}",
      "صفحة ${surah.pageNumber.toLocalized(context)}",
    ].join(' · ');

    return PrettierTap(
      onTap: () => _openMushaf(context),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(6, 8, 12, 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(12),
          border: context.cardBorder(),
          boxShadow: context.cardShadow(),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.12),
                ),
              ),
              child: IconButton(
                padding: EdgeInsets.zero,
                iconSize: 18,
                color: scheme.secondary,
                tooltip: S.of(context).play_surah,
                icon: const Icon(Icons.play_circle_outline),
                onPressed: () {
                  context.read<PlaybackCubit>().playFromAyah(
                    AyahIdentifier(surah: surah.number, ayah: 1),
                  );
                  _openMushaf(context);
                },
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    surah.name,
                    style: TS.bold16.copyWith(
                      fontSize: 18,
                      color: scheme.onSurface,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    meta,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: scheme.onSurface.withValues(alpha: 0.06),
                shape: BoxShape.circle,
                border: Border.all(
                  color: scheme.onSurface.withValues(alpha: 0.10),
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                surah.number.toLocalized(context),
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
