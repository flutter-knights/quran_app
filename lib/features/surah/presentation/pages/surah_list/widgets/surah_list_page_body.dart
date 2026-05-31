import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/router/app_router.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_list_skeleton.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/core/widgets/design/icon_chip.dart';
import 'package:quran_app/core/widgets/design/scroll_to_top_fab.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/last_read_card.dart';
import 'package:quran_app/features/search/presentation/cubit/search_cubit.dart';
import 'package:quran_app/features/search/presentation/cubit/search_state.dart';
import 'package:quran_app/features/surah/presentation/cubit/surah/surah_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/browse_tab.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/juz_browse_list.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/page_jumper_grid.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/search_results_view.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/start_reading_card.dart';
import 'package:quran_app/features/surah/presentation/pages/surah_list/widgets/surah_list_tile.dart';
import 'package:quran_app/generated/l10n.dart';

class SurahListPageBody extends StatefulWidget {
  const SurahListPageBody({super.key});

  @override
  State<SurahListPageBody> createState() => _SurahListPageBodyState();
}

class _SurahListPageBodyState extends State<SurahListPageBody> {
  BrowseTab _tab = BrowseTab.surah;
  final _scrollController = ScrollController();
  final _searchController = TextEditingController();
  final _searchFocus = FocusNode();

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    _searchFocus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Scaffold(
      backgroundColor: scheme.surface,
      body: SafeArea(
        child: Column(
          children: [
            AppScreenAppBar(
              label: S.of(context).the_noble_quran,
              title: S.of(context).surahs_appbar_title,
              trailing: IconChip(
                icon: const Icon(Icons.bookmark_outline),
                onPressed: () => context.push(AppRouter.bookmarksPath),
              ),
            ),
            _SearchHeader(
              controller: _searchController,
              focusNode: _searchFocus,
              selectedTab: _tab,
              onTabChanged: (t) => setState(() => _tab = t),
              onQueryChanged: (q) =>
                  context.read<SearchCubit>().queryChanged(q),
            ),
            Expanded(
              child: BlocBuilder<SearchCubit, SearchState>(
                builder: (context, search) {
                  return ScrollToTopFab(
                    controller: _scrollController,
                    child: CustomScrollView(
                      controller: _scrollController,
                      keyboardDismissBehavior:
                          ScrollViewKeyboardDismissBehavior.onDrag,
                      slivers: [
                        if (!search.isActive)
                          SliverPadding(
                            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                            sliver: SliverToBoxAdapter(
                              child: LastReadCard.maybeBuild(context) ??
                                  const StartReadingCard(),
                            ),
                          ),
                        if (search.isActive)
                          searchResultsSliver(context, search)
                        else
                          ..._browseSlivers(context),
                      ],
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _browseSlivers(BuildContext context) {
    switch (_tab) {
      case BrowseTab.surah:
        return _surahSlivers(context);
      case BrowseTab.juz:
        return [juzBrowseSliver(context)];
      case BrowseTab.page:
        return [pageJumperSliver(context)];
    }
  }

  List<Widget> _surahSlivers(BuildContext context) {
    final scheme = context.colorScheme;
    final surahs = context.watch<SurahCubit>().state;
    if (surahs.isEmpty) {
      return const [SliverFillRemaining(child: AppListSkeleton())];
    }
    return [
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 10),
        sliver: SliverToBoxAdapter(
          child: AppSectionHeader(
            label: S.of(context).all_surahs,
            trailing: Text(
              S.of(context).surahs_count(surahs.length.toLocalized(context)),
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.secondary,
              ),
            ),
          ),
        ),
      ),
      SliverPadding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        sliver: SliverList.separated(
          itemCount: surahs.length,
          separatorBuilder: (_, _) => const SizedBox(height: 8),
          itemBuilder: (_, i) => SurahListTile(surah: surahs[i]),
        ),
      ),
    ];
  }
}

/// Fixed (non-scrolling) header: a stable search field over the browse tabs.
/// The field lives OUTSIDE the scroll area's BlocBuilder so it is never torn
/// down on keystrokes — keyboard focus is preserved. The tabs hide while a
/// query is active (they only drive browse mode).
class _SearchHeader extends StatelessWidget {
  const _SearchHeader({
    required this.controller,
    required this.focusNode,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onQueryChanged,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final BrowseTab selectedTab;
  final ValueChanged<BrowseTab> onTabChanged;
  final ValueChanged<String> onQueryChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 8),
      child: Column(
        children: [
          TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onQueryChanged,
            textInputAction: TextInputAction.search,
            style: TextStyle(fontSize: 14, color: scheme.onSurface),
            decoration: InputDecoration(
              isDense: true,
              hintText: S.of(context).search_quran_hint,
              hintStyle:
                  TextStyle(fontSize: 14, color: scheme.onSurfaceVariant),
              prefixIcon: HugeIcon(
                icon: HugeIcons.strokeRoundedSearch01,
                size: 18,
                color: scheme.onSurfaceVariant,
              ),
              prefixIconConstraints: const BoxConstraints(minWidth: 40),
              suffixIcon: ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller,
                builder: (context, value, _) => value.text.isEmpty
                    ? const SizedBox.shrink()
                    : GestureDetector(
                        onTap: () {
                          controller.clear();
                          onQueryChanged('');
                        },
                        child: HugeIcon(
                          icon: HugeIcons.strokeRoundedCancel01,
                          size: 18,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
              ),
              suffixIconConstraints: const BoxConstraints(minWidth: 40),
              filled: true,
              fillColor: scheme.surfaceContainer,
              contentPadding: const EdgeInsets.symmetric(vertical: 12),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          BlocBuilder<SearchCubit, SearchState>(
            buildWhen: (a, b) => a.isActive != b.isActive,
            builder: (context, search) {
              if (search.isActive) return const SizedBox.shrink();
              return Padding(
                padding: const EdgeInsets.only(top: 10),
                child: AppSegmentedSelector<BrowseTab>(
                  expand: true,
                  selected: selectedTab,
                  onChanged: onTabChanged,
                  options: [
                    SegmentOption(
                      value: BrowseTab.surah,
                      label: S.of(context).tab_surahs,
                    ),
                    SegmentOption(
                      value: BrowseTab.juz,
                      label: S.of(context).tab_juz,
                    ),
                    SegmentOption(
                      value: BrowseTab.page,
                      label: S.of(context).tab_pages,
                    ),
                  ],
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}
