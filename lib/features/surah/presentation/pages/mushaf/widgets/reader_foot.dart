import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

class ReaderFoot extends StatelessWidget {
  const ReaderFoot({
    super.key,
    required this.colors,
    required this.onPrevious,
    required this.onNext,
    required this.onListen,
    required this.onMenu,
  });

  final MushafPaperColors colors;
  final VoidCallback? onPrevious;
  final VoidCallback? onNext;
  final VoidCallback? onListen;
  final VoidCallback onMenu;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    const pill = ButtonStyle(
      minimumSize: WidgetStatePropertyAll(Size(0, 56)),
      padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 8)),
    );
    Widget label(String text) => FittedBox(
      fit: BoxFit.scaleDown,
      child: Text(text, maxLines: 1, style: TS.semi14),
    );
    Widget arrow(
      String key,
      String tooltip,
      List<List<dynamic>> icon,
      VoidCallback? onPressed,
    ) => IconButton(
      key: ValueKey(key),
      tooltip: tooltip,
      onPressed: onPressed,
      icon: HugeIcon(
        icon: icon,
        color: onPressed == null
            ? colors.ink.withValues(alpha: 0.3)
            : colors.ink,
      ),
    );
    return Container(
      height: 64,
      color: colors.background,
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Row(
        spacing: 8,
        children: [
          arrow(
            'foot-previous',
            s.foot_previousPage,
            backArrowIcon(context),
            onPrevious,
          ),
          Expanded(
            child: FilledButton.icon(
              key: const ValueKey('foot-listen'),
              style: pill,
              onPressed: onListen,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedHeadphones,
                size: 18,
              ),
              label: label(s.foot_listen),
            ),
          ),
          Expanded(
            child: FilledButton.tonalIcon(
              key: const ValueKey('foot-menu'),
              style: pill.copyWith(
                backgroundColor: WidgetStatePropertyAll(colors.leaf),
                foregroundColor: WidgetStatePropertyAll(colors.ink),
              ),
              onPressed: onMenu,
              icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedMenu01,
                size: 18,
              ),
              label: label(s.foot_menu),
            ),
          ),
          arrow(
            'foot-next',
            s.foot_nextPage,
            forwardArrowIcon(context),
            onNext,
          ),
        ],
      ),
    );
  }
}
