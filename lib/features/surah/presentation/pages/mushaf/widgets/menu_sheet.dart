import 'dart:math' as math;

import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_segmented_selector.dart';
import 'package:quran_app/core/widgets/design/app_status_badge.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/widgets/surah_download_button.dart';
import 'package:quran_app/features/search/domain/entities/juz_browse_entry.dart';
import 'package:quran_app/features/search/domain/services/quran_browse_service.dart';
import 'package:quran_app/features/surah/presentation/utils/menu_query.dart';
import 'package:quran_app/features/surah/presentation/utils/surah_caption.dart';
import 'package:quran_app/generated/l10n.dart';

sealed class MenuAction extends Equatable {
  const MenuAction();

  @override
  List<Object?> get props => [];
}

final class MenuJump extends MenuAction {
  const MenuJump(this.page);

  final int page;

  @override
  List<Object?> get props => [page];
}

final class MenuOpenPlaces extends MenuAction {
  const MenuOpenPlaces();
}

final class MenuOpenDisplay extends MenuAction {
  const MenuOpenDisplay();
}

final class MenuPlayPage extends MenuAction {
  const MenuPlayPage();
}

class MenuSheet extends StatefulWidget {
  const MenuSheet({
    super.key,
    required this.currentSurah,
    required this.currentJuz,
    required this.juzEntries,
  });

  final int? currentSurah;
  final int currentJuz;
  final List<JuzBrowseEntry> juzEntries;

  static Future<MenuAction?> show(
    BuildContext context, {
    required int? currentSurah,
    required int currentJuz,
  }) => showModalBottomSheet<MenuAction>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    builder: (_) => MultiBlocProvider(
      providers: [
        BlocProvider.value(value: context.read<PlaybackCubit>()),
        BlocProvider.value(value: context.read<SurahDownloadCubit>()),
      ],
      child: MenuSheet(
        currentSurah: currentSurah,
        currentJuz: currentJuz,
        juzEntries: sl<QuranBrowseService>().juzEntries(),
      ),
    ),
  );

  @override
  State<MenuSheet> createState() => _MenuSheetState();
}

class _MenuSheetState extends State<MenuSheet> {
  final _searchKey = GlobalKey();
  var _surahs = true;
  MenuQuery _resolved = const MenuQueryNone();

  void _pop(MenuAction action) => Navigator.of(context).pop(action);

  @override
  Widget build(BuildContext context) {
    final pending = PendingS.of(context);
    final scheme = context.colorScheme;
    final inset = MediaQuery.viewInsetsOf(context).bottom;
    final search = KeyedSubtree(
      key: _searchKey,
      child: TextField(
        key: const ValueKey('menu-search'),
        keyboardType: TextInputType.text,
        textInputAction: TextInputAction.go,
        decoration: InputDecoration(hintText: pending.menu_searchHint),
        onSubmitted: (_) {
          if (_resolved case MenuQueryTarget(:final page)) {
            _pop(MenuJump(page));
          }
        },
        onChanged: (value) =>
            setState(() => _resolved = resolveMenuQuery(value)),
      ),
    );
    final result = switch (_resolved) {
      MenuQueryTarget(:final page, :final surah, :final juz) => Row(
        spacing: 8,
        children: [
          Expanded(
            child: Text(
              pending.menu_pageResult(
                page.toLocalized(context),
                surahDisplayName(context, surah),
                juz.toLocalized(context),
              ),
              style: TS.semi14,
            ),
          ),
          FilledButton(
            key: const ValueKey('menu-go'),
            onPressed: () => _pop(MenuJump(page)),
            child: Text(pending.menu_go),
          ),
        ],
      ),
      MenuQueryOutOfRange() => Align(
        alignment: AlignmentDirectional.centerStart,
        child: Text(
          pending.menu_pageRangeError,
          style: TS.medium14.copyWith(color: scheme.error),
        ),
      ),
      MenuQueryNone() => const SizedBox.shrink(),
    };
    return Padding(
      padding: EdgeInsets.only(bottom: inset),
      child: LayoutBuilder(
        builder: (context, constraints) => SizedBox(
          height: math.min(
            MediaQuery.sizeOf(context).height * 0.85,
            constraints.maxHeight,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: inset > 0
                ? SingleChildScrollView(
                    child: Column(spacing: 12, children: [search, result]),
                  )
                : Column(
                    spacing: 12,
                    children: [
                      IntrinsicHeight(
                        child: Row(
                          spacing: 8,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            _Tile(
                              key: const ValueKey('menu-tile-places'),
                              icon: HugeIcons.strokeRoundedLocation01,
                              label: pending.menu_places,
                              onTap: () => _pop(const MenuOpenPlaces()),
                            ),
                            _Tile(
                              key: const ValueKey('menu-tile-display'),
                              icon: HugeIcons.strokeRoundedSettings02,
                              label: pending.menu_display,
                              onTap: () => _pop(const MenuOpenDisplay()),
                            ),
                            _Tile(
                              key: const ValueKey('menu-tile-play'),
                              icon: HugeIcons.strokeRoundedHeadphones,
                              label: pending.mushaf_playWholePage,
                              onTap: () => _pop(const MenuPlayPage()),
                            ),
                          ],
                        ),
                      ),
                      search,
                      result,
                      AppSegmentedSelector<bool>(
                        expand: true,
                        selected: _surahs,
                        onChanged: (value) => setState(() => _surahs = value),
                        options: [
                          SegmentOption(
                            value: true,
                            label: S.of(context).tab_surahs,
                          ),
                          SegmentOption(
                            value: false,
                            label: S.of(context).tab_juz,
                          ),
                        ],
                      ),
                      Expanded(
                        child: KeyedSubtree(
                          key: ValueKey(_surahs),
                          child: _surahs
                              ? _IndexList(
                                  itemCount: quran.totalSurahCount,
                                  current: widget.currentSurah,
                                  itemBuilder: (context, i) =>
                                      _surahRow(context, i + 1),
                                )
                              : _IndexList(
                                  itemCount: widget.juzEntries.length,
                                  current: widget.currentJuz,
                                  itemBuilder: (context, i) =>
                                      _juzRow(context, widget.juzEntries[i]),
                                ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }

  Widget _surahRow(BuildContext context, int n) {
    final page = quran.getPageNumber(n, 1);
    return _Row(
      key: ValueKey('menu-surah-$n'),
      number: n,
      title: surahDisplayName(context, n),
      caption: surahCaption(context, n),
      page: page,
      here: n == widget.currentSurah,
      trailing: SurahDownloadButton(surah: n),
      onTap: () => _pop(MenuJump(page)),
    );
  }

  Widget _juzRow(BuildContext context, JuzBrowseEntry entry) => _Row(
    key: ValueKey('menu-juz-${entry.number}'),
    number: entry.number,
    title: S.of(context).juz_label(entry.number.toLocalized(context)),
    caption: '${entry.firstSurahArabicName} – ${entry.lastSurahArabicName}',
    page: entry.firstPage,
    here: entry.number == widget.currentJuz,
    onTap: () => _pop(MenuJump(entry.firstPage)),
  );
}

class _IndexList extends StatefulWidget {
  const _IndexList({
    required this.itemCount,
    required this.current,
    required this.itemBuilder,
  });

  final int itemCount;
  final int? current;
  final IndexedWidgetBuilder itemBuilder;

  @override
  State<_IndexList> createState() => _IndexListState();
}

class _IndexListState extends State<_IndexList> {
  final _controller = ScrollController();
  final _first = GlobalKey();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _revealCurrent());
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _revealCurrent() {
    final current = widget.current;
    final row = _first.currentContext?.size;
    if (!mounted || current == null || row == null || !_controller.hasClients) {
      return;
    }
    _controller.jumpTo(
      math.min(
        math.max(0, current - 2) * row.height,
        _controller.position.maxScrollExtent,
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ListView.builder(
    key: const ValueKey('menu-list'),
    controller: _controller,
    itemCount: widget.itemCount,
    itemBuilder: (context, i) {
      final row = widget.itemBuilder(context, i);
      return i == 0 ? KeyedSubtree(key: _first, child: row) : row;
    },
  );
}

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final List<List<dynamic>> icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => Expanded(
    child: SurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 12),
      onTap: onTap,
      child: Column(
        spacing: 6,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HugeIcon(icon: icon, size: 24, color: context.colorScheme.primary),
          Text(label, style: TS.semi14, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class _Row extends StatelessWidget {
  const _Row({
    super.key,
    required this.number,
    required this.title,
    required this.caption,
    required this.page,
    required this.here,
    required this.onTap,
    this.trailing,
  });

  final int number;
  final String title;
  final String caption;
  final int page;
  final bool here;
  final VoidCallback onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final pending = PendingS.of(context);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Row(
            spacing: 12,
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: scheme.onSurface.withValues(alpha: 0.06),
                  shape: BoxShape.circle,
                ),
                child: Text(number.toLocalized(context), style: TS.extra16),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: TS.bold16),
                    Text(
                      caption,
                      style: TS.medium14.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      pending.mushaf_pageNumber(page.toLocalized(context)),
                      style: TS.medium14.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (here)
                AppStatusBadge(
                  color: scheme.primary,
                  label: pending.menu_youAreHere,
                ),
              ?trailing,
            ],
          ),
        ),
      ),
    );
  }
}
