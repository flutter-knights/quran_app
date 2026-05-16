import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/custom_app_bar.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/generated/l10n.dart';

class HadithView extends StatelessWidget {
  final Hadith hadith;
  const HadithView({super.key, required this.hadith});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(
        title: Text(
          '${S.current.hadith_number_label} ${hadith.hadithNumber.toLocalized(context)}',
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _ChapterCard(hadith: hadith),
              const SizedBox(height: 24),
              _HadithSection(
                title: S.current.arabic_label,
                content: hadith.arabicHadith,
                textStyle: TS.bold24.amiriQuran.copyWith(
                  height: 1.6,
                  color: context.colorScheme.primary,
                ),
                textAlign: TextAlign.right,
              ),
              const Divider(height: 48),
              _HadithSection(
                title: S.current.translation_label,
                content: hadith.englishHadith,
                textStyle: TS.medium16.copyWith(
                  height: 1.5,
                  color: context.colorScheme.onSurface,
                ),
                textAlign: TextAlign.left,
              ),
              if (hadith.englishNarrator.isNotEmpty) ...[
                const SizedBox(height: 24),
                _NarratorInfo(narrator: hadith.englishNarrator),
              ],
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChapterCard extends StatelessWidget {
  final Hadith hadith;
  const _ChapterCard({required this.hadith});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: context.colorScheme.outlineVariant.withAlpha(50),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StatusBadge(status: hadith.status),
              Text(
                '${S.current.chapter_label} ${hadith.chapter?.chapterNumber.toLocalized(context) ?? ""}',
                style: TS.bold14.copyWith(
                  color: context.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (hadith.chapter != null) ...[
            Text(
              hadith.chapter!.chapterArabic,
              style: TS.bold16.amiri.copyWith(
                color: context.colorScheme.primary,
              ),
              textAlign: TextAlign.right,
            ),
            const SizedBox(height: 4),
            Text(
              hadith.chapter!.chapterEnglish,
              style: TS.medium14.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusBadge extends StatelessWidget {
  final HadithStatus status;
  const _StatusBadge({required this.status});

  @override
  Widget build(BuildContext context) {
    Color color;
    String label;

    switch (status) {
      case HadithStatus.sahih:
        color = Colors.green;
        label = S.current.status_sahih;
      case HadithStatus.hasan:
        color = Colors.orange;
        label = S.current.status_hasan;
      case HadithStatus.daeef:
        color = Colors.red;
        label = S.current.status_daeef;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withAlpha(100)),
      ),
      child: Text(label, style: TS.bold12.copyWith(color: color)),
    );
  }
}

class _HadithSection extends StatelessWidget {
  final String title;
  final String content;
  final TextStyle textStyle;
  final TextAlign textAlign;

  const _HadithSection({
    required this.title,
    required this.content,
    required this.textStyle,
    required this.textAlign,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: TS.bold14.copyWith(
            color: context.colorScheme.onSurfaceVariant,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 12),
        Text(content, style: textStyle, textAlign: textAlign),
      ],
    );
  }
}

class _NarratorInfo extends StatelessWidget {
  final String narrator;
  const _NarratorInfo({required this.narrator});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: context.colorScheme.primaryContainer.withAlpha(30),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: context.colorScheme.primary.withAlpha(50)),
      ),
      child: Row(
        children: [
          Icon(
            Icons.info_outline,
            size: 18,
            color: context.colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              narrator,
              style: TS.medium14.copyWith(
                color: context.colorScheme.onSurfaceVariant,
                fontStyle: FontStyle.italic,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
