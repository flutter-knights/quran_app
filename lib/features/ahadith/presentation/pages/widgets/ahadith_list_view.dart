import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/design/app_screen_app_bar.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/icon_chip.dart';
import 'package:quran_app/core/widgets/design/scroll_to_top_fab.dart';
import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/ahadith_cubit.dart';
import 'package:quran_app/core/widgets/design/app_list_skeleton.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/download_book_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/cubit/search_hadith_cubit.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/ahadith_list_item.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/books_list_view.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/chapter_picker_sheet.dart';
import 'package:quran_app/features/ahadith/presentation/utils/hadith_list_filter.dart';
import 'package:quran_app/generated/l10n.dart';

class AhadithListView extends StatefulWidget {
  final String bookSlug;
  const AhadithListView({super.key, required this.bookSlug});

  @override
  State<AhadithListView> createState() => _AhadithListViewState();
}

class _AhadithListViewState extends State<AhadithListView> {
  late final ScrollController _scrollController;
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  HadithListFilter _filter = const HadithListFilter();

  bool get _searching => _query.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController()..addListener(_onScroll);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _onScroll() {
    if (_searching) return; // search results aren't paginated
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent * 0.8) {
      context.read<AhadithCubit>().fetchAhadith(bookSlug: widget.bookSlug);
    }
  }

  void _onQueryChanged(String value) {
    setState(() => _query = value);
    context
        .read<SearchHadithCubit>()
        .searchAhadith(value, widget.bookSlug, filter: _filter);
  }

  void _clearSearch() {
    _searchController.clear();
    _onQueryChanged('');
  }

  void _updateFilter(HadithListFilter filter) {
    setState(() => _filter = filter);
    final isDownloaded = context
        .read<DownloadBookCubit>()
        .state
        .downloadedBooks
        .contains(widget.bookSlug);
    context.read<AhadithCubit>().applyFilter(filter, isDownloaded: isDownloaded);
    // Keep an active search in sync with the filter.
    context.read<SearchHadithCubit>().reapplyFilter(filter);
  }

  String _bookTitle(BuildContext context) {
    for (final b in getHadithBooks(context)) {
      if (b.slug == widget.bookSlug) return b.title;
    }
    return widget.bookSlug;
  }

  int? _bookHadithCount(BuildContext context) {
    for (final b in getHadithBooks(context)) {
      if (b.slug == widget.bookSlug) return b.hadithCount;
    }
    return null;
  }

  Future<void> _openFilterSheet() async {
    final cubit = context.read<AhadithCubit>();
    final chapters = cubit.chapters;
    final statuses = cubit.availableStatuses;
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: context.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => _FilterSheet(
        chapters: chapters,
        statuses: statuses,
        filter: _filter,
        onChanged: _updateFilter,
      ),
    );
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
              label: S.of(context).hadith_screen_title,
              title: _bookTitle(context),
              trailing: IconChip(
                icon: HugeIcon(
                  icon: HugeIcons.strokeRoundedFilterHorizontal,
                  color: _filter.isActive ? scheme.primary : null,
                ),
                onPressed: _openFilterSheet,
              ),
            ),
            _SearchField(
              controller: _searchController,
              onChanged: _onQueryChanged,
              onClear: _clearSearch,
            ),
            BlocBuilder<AhadithCubit, AhadithState>(
              builder: (context, _) {
                final available =
                    context.read<AhadithCubit>().availableStatuses;
                // A single-grade book (e.g. all-Sahih) has nothing to filter.
                if (available.length <= 1) return const SizedBox.shrink();
                return _StatusChipsRow(
                  statuses: available,
                  filter: _filter,
                  onToggle: (s) => _updateFilter(_filter.toggleStatus(s)),
                );
              },
            ),
            Expanded(
              child: ScrollToTopFab(
                controller: _scrollController,
                child: _searching ? _buildSearchResults() : _buildBrowse(),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBrowse() {
    final scheme = context.colorScheme;
    return BlocBuilder<AhadithCubit, AhadithState>(
      builder: (context, state) {
        if (state is AhadithError && !state.paginationError) {
          return const Center(child: Text('error'));
        }
        if (state is AhadithLoading) {
          return const AppListSkeleton();
        }
        if (state is AhadithLoaded || state is AhadithLoadingMore) {
          final List<Hadith> all = (state is AhadithLoaded)
              ? state.ahadith
              : (state as AhadithLoadingMore).oldAhadith;
          final bool lastPage =
              (state is AhadithLoaded) ? state.lastPage : false;
          final ahadith = applyHadithFilters(all, _filter);
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 10),
                child: AppSectionHeader(
                  label: S.of(context).ahadith_section,
                  trailing: Text(
                    S.of(context).ahadith_count(
                          (_filter.isActive
                                  ? ahadith.length
                                  : (_bookHadithCount(context) ?? all.length))
                              .toLocalized(context),
                        ),
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: scheme.secondary,
                    ),
                  ),
                ),
              ),
              Expanded(
                child: ListView.separated(
                  controller: _scrollController,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
                  itemCount: lastPage ? ahadith.length : ahadith.length + 1,
                  cacheExtent: 400,
                  separatorBuilder: (_, _) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    if (index >= ahadith.length) {
                      return const _LoadMoreSkeleton();
                    }
                    return AhadithListItem(
                      hadith: ahadith[index],
                      bookSlug: widget.bookSlug,
                    );
                  },
                ),
              ),
            ],
          );
        }
        return const SizedBox();
      },
    );
  }

  Widget _buildSearchResults() {
    return BlocBuilder<SearchHadithCubit, SearchHadithState>(
      builder: (context, state) {
        if (state is SearchHadithLoading || state is SearchHadithInitial) {
          return const AppListSkeleton();
        }
        if (state is SearchHadithError) {
          return Center(child: Text(state.message));
        }
        if (state is SearchHadithLoaded) {
          final results = applyHadithFilters(state.hadithList, _filter);
          if (results.isEmpty) {
            return Center(child: Text(S.of(context).search_no_results));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
            itemCount: results.length,
            separatorBuilder: (_, _) => const SizedBox(height: 10),
            itemBuilder: (context, index) => AhadithListItem(
              hadith: results[index],
              bookSlug: widget.bookSlug,
            ),
          );
        }
        return const SizedBox();
      },
    );
  }
}

/// Single shimmer card shown while the next page loads.
class _LoadMoreSkeleton extends StatelessWidget {
  const _LoadMoreSkeleton();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Skeletonizer(
      child: SurfaceCard(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        radius: 12,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'عنوان تجريبي قيد التحميل',
              style: TextStyle(fontSize: 15, color: scheme.onSurface),
            ),
            const SizedBox(height: 8),
            Text(
              'سطر فرعي يوضح حالة التحميل',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchField extends StatelessWidget {
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.onClear,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: TextStyle(fontSize: 14, color: scheme.onSurface),
        decoration: InputDecoration(
          isDense: true,
          hintText: S.of(context).search_hadith_hint,
          hintStyle: TextStyle(
            fontSize: 14,
            color: scheme.onSurfaceVariant,
          ),
          prefixIcon: HugeIcon(
            icon: HugeIcons.strokeRoundedSearch01,
            size: 18,
            color: scheme.onSurfaceVariant,
          ),
          prefixIconConstraints: const BoxConstraints(minWidth: 40),
          suffixIcon: controller.text.isEmpty
              ? null
              : GestureDetector(
                  onTap: onClear,
                  child: HugeIcon(
                    icon: HugeIcons.strokeRoundedCancel01,
                    size: 18,
                    color: scheme.onSurfaceVariant,
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
    );
  }
}

class _StatusChipsRow extends StatelessWidget {
  const _StatusChipsRow({
    required this.statuses,
    required this.filter,
    required this.onToggle,
  });

  final Set<HadithStatus> statuses;
  final HadithListFilter filter;
  final ValueChanged<HadithStatus> onToggle;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        children: [
          // Iterate the enum for canonical order, keeping only available grades.
          for (final status in HadithStatus.values)
            if (statuses.contains(status)) ...[
            _StatusChip(
              label: statusLabel(context, status),
              color: statusColor(status),
              selected: filter.status == status,
              onTap: () => onToggle(status),
            ),
            const SizedBox(width: 8),
          ],
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected
                ? color
                : scheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatefulWidget {
  const _FilterSheet({
    required this.chapters,
    required this.statuses,
    required this.filter,
    required this.onChanged,
  });

  final List<Chapter> chapters;
  final Set<HadithStatus> statuses;
  final HadithListFilter filter;
  final ValueChanged<HadithListFilter> onChanged;

  @override
  State<_FilterSheet> createState() => _FilterSheetState();
}

class _FilterSheetState extends State<_FilterSheet> {
  late HadithListFilter _filter = widget.filter;

  void _apply(HadithListFilter next) {
    setState(() => _filter = next);
    widget.onChanged(next);
  }

  Chapter? get _selectedChapter {
    if (_filter.chapterId == null) return null;
    for (final c in widget.chapters) {
      if (c.id == _filter.chapterId) return c;
    }
    return null;
  }

  Future<void> _openChapterPicker() async {
    final result = await ChapterPickerSheet.show(
      context,
      chapters: widget.chapters,
      selectedChapterId: _filter.chapterId,
    );
    if (result == null) return; // dismissed
    _apply(_filter.withChapter(result.chapterId));
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final selected = _selectedChapter;
    final hasGrades = widget.statuses.length > 1;

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 14),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  S.of(context).filters_title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                TextButton(
                  onPressed: () {
                    _apply(const HadithListFilter());
                    Navigator.of(context).pop();
                  },
                  child: Text(S.of(context).filter_clear),
                ),
              ],
            ),
            if (hasGrades) ...[
              const SizedBox(height: 6),
              Text(
                S.of(context).filter_status_label,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final status in HadithStatus.values)
                    if (widget.statuses.contains(status))
                      _GradePill(
                        label: statusLabel(context, status),
                        color: statusColor(status),
                        selected: _filter.status == status,
                        onTap: () => _apply(_filter.toggleStatus(status)),
                      ),
                ],
              ),
            ],
            const SizedBox(height: 14),
            Text(
              S.of(context).filter_chapter_label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: widget.chapters.isEmpty ? null : _openChapterPicker,
              borderRadius: BorderRadius.circular(12),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainer,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        selected == null
                            ? S.of(context).filter_all_chapters
                            : '${selected.chapterNumber}. ${isRtl ? selected.chapterArabic : selected.chapterEnglish}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    Icon(
                      isRtl ? Icons.chevron_left : Icons.chevron_right,
                      color: scheme.onSurfaceVariant,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradePill extends StatelessWidget {
  const _GradePill({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? color.withValues(alpha: 0.16) : scheme.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: selected ? color : scheme.onSurface.withValues(alpha: 0.12),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: selected ? color : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
