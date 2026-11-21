import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/khatam_medallion.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

class RunningHead extends StatelessWidget {
  const RunningHead({
    super.key,
    required this.surahName,
    required this.page,
    required this.juz,
    required this.hizb,
    required this.colors,
    required this.onBack,
    required this.onOpenMenu,
  });

  final String surahName;
  final int page;
  final int juz;
  final int hizb;
  final MushafPaperColors colors;
  final VoidCallback onBack;
  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final hairline = BorderSide(color: colors.accent);
    return Container(
      height: 64,
      color: colors.background,
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(
                  child: Row(
                    children: [
                      IconButton(
                        key: const ValueKey('head-back'),
                        tooltip: MaterialLocalizations.of(
                          context,
                        ).backButtonTooltip,
                        onPressed: onBack,
                        icon: HugeIcon(
                          icon: backArrowIcon(context),
                          color: colors.ink,
                        ),
                      ),
                      Flexible(
                        child: InkWell(
                          key: const ValueKey('head-surah'),
                          onTap: onOpenMenu,
                          child: Text(
                            surahName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TS.bold16.copyWith(color: colors.ink),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                KhatamMedallion(
                  label: page.toLocalized(context),
                  colors: colors,
                ),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsetsDirectional.only(end: 16),
                    child: Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: InkWell(
                        key: const ValueKey('head-juz'),
                        onTap: onOpenMenu,
                        child: Text(
                          s.head_juzHizb(
                            juz.toLocalized(context),
                            hizb.toLocalized(context),
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TS.medium14.copyWith(color: colors.ink2),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Container(
            height: 4,
            decoration: BoxDecoration(
              border: Border(top: hairline, bottom: hairline),
            ),
          ),
        ],
      ),
    );
  }
}
