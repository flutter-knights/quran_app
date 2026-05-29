import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/widgets/design/app_bar_center_title.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/core/widgets/design/icon_chip.dart';
import 'package:hugeicons/hugeicons.dart';

/// Standard screen header: a back chip on the start, a centered [title] (with an
/// optional eyebrow [label]) and an optional [trailing] action on the end.
/// When [trailing] is null a matching-width spacer keeps the title centered.
class AppScreenAppBar extends StatelessWidget {
  const AppScreenAppBar({
    super.key,
    required this.title,
    this.label,
    this.trailing,
    this.onBack,
  });

  final String title;
  final String? label;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Container(
      height: 60,
      padding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: scheme.onSurface.withValues(alpha: 0.06)),
        ),
      ),
      child: Row(
        children: [
          IconChip(
            icon: HugeIcon(icon: backArrowIcon(context)),
            onPressed: onBack ?? () => Navigator.of(context).maybePop(),
          ),
          const Spacer(),
          AppBarCenterTitle(label: label, title: title),
          const Spacer(),
          trailing ?? const SizedBox(width: 38),
        ],
      ),
    );
  }
}
