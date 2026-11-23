import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_status_badge.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/features/ayah_share/presentation/widgets/ayah_share_sheet.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/domain/entities/normalized_rect.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/ayah_strip.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/tafsir/presentation/widgets/tafsir_section.dart';
import 'package:quran_app/generated/l10n.dart';

class AyahStudyLeaf extends StatelessWidget {
  const AyahStudyLeaf({
    super.key,
    required this.ayah,
    required this.page,
    required this.lines,
    required this.colors,
    required this.onBack,
    this.onPrevious,
    this.onNext,
  });

  final AyahIdentifier ayah;
  final int page;
  final List<NormalizedRect> lines;
  final MushafPaperColors colors;
  final VoidCallback onBack;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final strings = S.of(context);
    final title = s.playback_mediaTitle(
      surahDisplayName(context, ayah.surah),
      ayah.ayah.toLocalized(context),
    );
    final stepStyle = colors
        .paperButton(outlined: true)
        .copyWith(minimumSize: const WidgetStatePropertyAll(Size(0, 48)));
    return Material(
      color: colors.leaf,
      shape: Border(top: BorderSide(color: colors.accent)),
      child: Column(
        children: [
          GestureDetector(
            onVerticalDragEnd: (details) {
              if ((details.primaryVelocity ?? 0) > 300) onBack();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 4,
                children: [
                  Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TS.bold16.copyWith(color: colors.ink),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Flexible(
                        child: TextButton.icon(
                          key: const ValueKey('study-back'),
                          style: colors.paperButton(),
                          onPressed: onBack,
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedArrowDown01,
                            size: 18,
                          ),
                          label: Text(
                            s.tafsir_backToMushaf,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TS.semi14,
                          ),
                        ),
                      ),
                      Flexible(
                        child: TextButton.icon(
                          key: const ValueKey('study-share'),
                          style: colors.paperButton(),
                          onPressed: () =>
                              AyahShareSheet.show(context, ayah: ayah),
                          icon: const HugeIcon(
                            icon: HugeIcons.strokeRoundedShare08,
                            size: 18,
                          ),
                          label: Text(
                            strings.share,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TS.semi14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  AyahStrip(page: page, lines: lines, colors: colors),
                  Text(
                    s.tafsir_behind,
                    style: TS.medium14.copyWith(color: colors.ink2),
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      _Chip(
                        key: const ValueKey('study-chip-tafsir'),
                        label: s.tafsir_sectionTafsir,
                        colors: colors,
                        selected: true,
                      ),
                      _Chip(
                        key: const ValueKey('study-chip-translation'),
                        label: s.tafsir_sectionTranslation,
                        colors: colors,
                      ),
                      _Chip(
                        key: const ValueKey('study-chip-words'),
                        label: s.tafsir_sectionWords,
                        colors: colors,
                      ),
                      _Chip(
                        key: const ValueKey('study-chip-note'),
                        label: s.tafsir_sectionNote,
                        colors: colors,
                      ),
                    ],
                  ),
                  TafsirSection(
                    ayah: ayah,
                    ink: colors.ink,
                    mutedInk: colors.ink2,
                    buttonStyle: colors.paperButton(),
                  ),
                  Row(
                    spacing: 8,
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('study-previous'),
                          style: stepStyle,
                          onPressed: onPrevious,
                          icon: HugeIcon(
                            icon: backArrowIcon(context),
                            size: 18,
                          ),
                          label: Text(
                            strings.playback_previous,
                            textAlign: TextAlign.center,
                            style: TS.semi14,
                          ),
                        ),
                      ),
                      Expanded(
                        child: OutlinedButton.icon(
                          key: const ValueKey('study-next'),
                          style: stepStyle,
                          onPressed: onNext,
                          iconAlignment: IconAlignment.end,
                          icon: HugeIcon(
                            icon: forwardArrowIcon(context),
                            size: 18,
                          ),
                          label: Text(
                            strings.playback_next,
                            textAlign: TextAlign.center,
                            style: TS.semi14,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    super.key,
    required this.label,
    required this.colors,
    this.selected = false,
  });

  final String label;
  final MushafPaperColors colors;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      enabled: selected,
      child: Container(
        constraints: const BoxConstraints(minHeight: 48),
        padding: const EdgeInsetsDirectional.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          border: Border.all(color: colors.accent),
          borderRadius: BorderRadius.circular(24),
          color: selected ? colors.accent.withValues(alpha: 0.16) : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            Flexible(
              child: Text(
                label,
                style: TS.semi14.copyWith(
                  color: selected ? colors.ink : colors.ink2,
                ),
              ),
            ),
            if (!selected)
              AppStatusBadge(
                color: colors.ink2,
                label: PendingS.of(context).tafsir_sectionLater,
                showDot: false,
              ),
          ],
        ),
      ),
    );
  }
}
