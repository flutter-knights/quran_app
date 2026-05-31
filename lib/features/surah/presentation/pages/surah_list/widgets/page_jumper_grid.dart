// lib/features/surah/presentation/pages/surah_list/widgets/page_jumper_grid.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';

/// Sliver grid of mushaf pages 1..604; tapping a cell opens that page.
Widget pageJumperSliver(BuildContext context) {
  const totalPages = 604;
  return SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
    sliver: SliverGrid(
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 6,
        mainAxisSpacing: 8,
        crossAxisSpacing: 8,
        childAspectRatio: 1,
      ),
      delegate: SliverChildBuilderDelegate(
        (context, i) => _PageCell(page: i + 1),
        childCount: totalPages,
      ),
    ),
  );
}

class _PageCell extends StatelessWidget {
  const _PageCell({required this.page});
  final int page;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return PrettierTap(
      onTap: () => context.push(AppRouter.mushafPath, extra: page),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: scheme.surfaceContainer,
          borderRadius: BorderRadius.circular(10),
          border: context.cardBorder(),
        ),
        child: Text(
          page.toLocalized(context),
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
