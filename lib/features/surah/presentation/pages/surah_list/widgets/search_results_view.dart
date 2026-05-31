// lib/features/surah/presentation/pages/surah_list/widgets/search_results_view.dart
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/search/domain/entities/search_result.dart';
import 'package:quran_app/features/search/presentation/cubit/search_state.dart';
import 'package:quran_app/generated/l10n.dart';

import 'ayah_result_tile.dart';
import 'surah_result_tile.dart';

/// Builds the grouped search-result slivers (jump suggestions → surahs →
/// ayahs). Returns a single sliver (a [SliverMainAxisGroup]) so it slots
/// straight into the page's [CustomScrollView].
Widget searchResultsSliver(BuildContext context, SearchState search) {
  final scheme = context.colorScheme;
  final r = search.results;

  if (!search.isSearching && r.isEmpty) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(16, 40, 16, 32),
      sliver: SliverToBoxAdapter(
        child: Center(
          child: Text(
            S.of(context).quran_search_no_results,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }

  final groups = <Widget>[];

  // Jump suggestions.
  for (final s in r.suggestions) {
    groups.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        sliver: SliverToBoxAdapter(child: _JumpTile(suggestion: s)),
      ),
    );
  }

  // Surahs.
  if (r.surahs.isNotEmpty) {
    groups.add(_header(context, S.of(context).search_section_surahs,
        r.surahs.length.toLocalized(context)));
    groups.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        sliver: SliverList.separated(
          itemCount: r.surahs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => SurahResultTile(result: r.surahs[i]),
        ),
      ),
    );
  }

  // Ayahs.
  if (r.ayahs.isNotEmpty) {
    groups.add(_header(context, S.of(context).search_section_ayahs,
        r.ayahTotalMatches.toLocalized(context)));
    groups.add(
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
        sliver: SliverList.separated(
          itemCount: r.ayahs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => AyahResultTile(result: r.ayahs[i]),
        ),
      ),
    );
    final hidden = r.ayahTotalMatches - r.ayahs.length;
    if (hidden > 0) {
      groups.add(
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
          sliver: SliverToBoxAdapter(
            child: Text(
              S.of(context).search_more_results(hidden.toLocalized(context)),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ),
      );
    }
  }

  groups.add(const SliverToBoxAdapter(child: SizedBox(height: 24)));
  return SliverMainAxisGroup(slivers: groups);
}

Widget _header(BuildContext context, String label, String count) {
  return SliverPadding(
    padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
    sliver: SliverToBoxAdapter(
      child: AppSectionHeader(
        label: label,
        trailing: Text(
          count,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w600,
            color: context.colorScheme.secondary,
          ),
        ),
      ),
    ),
  );
}

class _JumpTile extends StatelessWidget {
  const _JumpTile({required this.suggestion});
  final JumpSuggestion suggestion;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final label = suggestion.kind == JumpKind.page
        ? S.of(context).go_to_page(suggestion.number.toLocalized(context))
        : S.of(context).go_to_juz(suggestion.number.toLocalized(context));
    return PrettierTap(
      onTap: () =>
          context.push(AppRouter.mushafPath, extra: suggestion.page),
      child: Container(
        padding: const EdgeInsetsDirectional.fromSTEB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.30)),
        ),
        child: Row(
          children: [
            Icon(Icons.arrow_forward, size: 16, color: scheme.primary),
            const SizedBox(width: 10),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: scheme.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
