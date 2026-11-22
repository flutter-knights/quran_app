import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

class NoticeChip extends StatelessWidget {
  const NoticeChip({
    super.key,
    required this.label,
    required this.onTap,
    required this.colors,
    this.actionLabel,
    this.onAction,
  });

  final String label;
  final VoidCallback onTap;
  final MushafPaperColors colors;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Material(
        color: colors.leaf,
        clipBehavior: Clip.antiAlias,
        shape: StadiumBorder(side: BorderSide(color: colors.accent)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Flexible(
              child: InkWell(
                key: const ValueKey('notice-chip'),
                onTap: onTap,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(minHeight: 48),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Center(
                      widthFactor: 1,
                      child: Text(
                        label,
                        style: TS.medium14.copyWith(color: colors.ink),
                      ),
                    ),
                  ),
                ),
              ),
            ),
            if (actionLabel != null)
              TextButton(
                key: const ValueKey('notice-action'),
                style: colors.paperButton(),
                onPressed: onAction,
                child: Text(actionLabel!, style: TS.semi14),
              ),
          ],
        ),
      ),
    );
  }
}
