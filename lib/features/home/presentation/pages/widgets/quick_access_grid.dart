import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/generated/l10n.dart';

class QuickAccessGrid extends StatelessWidget {
  const QuickAccessGrid({super.key});

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 4,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 0.78,
      children: [
        _QuickTile(
          icon: HugeIcons.strokeRoundedBookOpen01,
          label: S.of(context).quran_screen_title,
          onTap: () => context.push(AppRouter.surahListPath),
        ),
        _QuickTile(
          icon: HugeIcons.strokeRoundedBookmark02,
          label: S.of(context).hadith_screen_title,
          onTap: () => context.push(AppRouter.booksPath),
        ),
        _QuickTile(
          icon: HugeIcons.strokeRoundedFavourite,
          label: S.of(context).bookmarks_screen_title,
          enabled: false,
        ),
        _QuickTile(
          icon: HugeIcons.strokeRoundedSettings01,
          label: S.of(context).settings_screen_title,
          onTap: () => context.push(AppRouter.settingsPath),
        ),
      ],
    );
  }
}

class _QuickTile extends StatelessWidget {
  const _QuickTile({
    required this.icon,
    required this.label,
    this.onTap,
    this.enabled = true,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback? onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final tile = Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: context.cardBorder(),
        boxShadow: context.cardShadow(),
      ),
      alignment: Alignment.center,
      child: HugeIcon(icon: icon, size: 24, color: scheme.onSurface),
    );
    return Opacity(
      opacity: enabled ? 1 : 0.4,
      child: Column(
        children: [
          Expanded(
            child: enabled ? PrettierTap(onTap: onTap, child: tile) : tile,
          ),
          const SizedBox(height: 6),
          Text(
            label,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: scheme.onSurface,
              height: 1.3,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
