import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quran/quran.dart' as quran;

import '../../../../../config/router/app_router.dart';
import '../../../../../config/router/now_playing_route.dart';
import '../../../../../core/constants/mushaf_reading_mode.dart';
import '../../../../../core/di/dependency_injection.dart';
import '../../../../../core/helper functions/locale_helpers.dart';
import '../../utils/mushaf_paper_colors.dart';
import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../quran_playback/domain/services/quran_meta_service.dart';
import '../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../../quran_playback/presentation/cubit/playback/playback_state.dart';
import '../../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../domain/entities/last_read.dart';
import '../../cubit/last_read/last_read_cubit.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';
import '../../cubit/mushaf/mushaf_state.dart';
import '../../utils/follow_playback.dart';
import '../../utils/page_bounds.dart';
import '../../utils/reader_rules.dart';
import 'last_read_saver.dart';
import '../../utils/mushaf_args.dart';
import 'page_turn_tracker.dart';
import 'widgets/ayah_leaf.dart';
import 'widgets/display_sheet.dart';
import 'widgets/menu_sheet.dart';
import 'widgets/mushaf_page_view.dart';
import 'widgets/player_leaf.dart';
import 'widgets/reader_foot.dart';
import 'widgets/running_head.dart';

class MushafPage extends StatefulWidget {
  const MushafPage({super.key, required this.args});
  final MushafArgs args;

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> with WidgetsBindingObserver {
  late final PageController _pageController;

  // Not `final` — recreated in didChangeDependencies when the screen width
  // changes (orientation flip) so the scroll position is always initialised
  // to the correct page BEFORE the first paint. This eliminates the one-frame
  // flash of page 1 that a post-frame jumpTo would cause.
  late ScrollController _scrollController;

  late final MushafCubit _mushafCubit;
  late final PlaybackCubit _playbackCubit;
  late final LastReadCubit _lastReadCubit;

  late final LastReadSaver _lastReadSaver;
  final _turns = PageTurnTracker();
  StreamSubscription<int>? _pageSub;
  late final StreamSubscription<void> _resumeSub;

  // Gap between pages in scroll mode (logical pixels).
  static const double _scrollPageGap = 4.0;

  // Tracks which mode was rendered last so _buildReadingArea can detect a
  // real mode switch vs. a rebuild caused by an unrelated settings change.
  MushafReadingMode? _lastBuiltMode;

  // Height of one Mushaf page in scroll mode. Derived from the available
  // width ÷ the page image aspect ratio. Updated in didChangeDependencies.
  double _scrollPageHeight = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.args.page - 1);
    _pageController.addListener(_precacheFromPageController);

    // Placeholder — replaced with the correctly-offset controller in
    // didChangeDependencies, which runs before the first build.
    _scrollController = ScrollController();

    _mushafCubit = context.read<MushafCubit>();
    _playbackCubit = context.read<PlaybackCubit>();
    _lastReadCubit = context.read<LastReadCubit>();
    _resumeSub = nowPlayingResume.stream.listen(
      (_) => _mushafCubit.resumeFollow(),
    );

    _lastReadSaver = LastReadSaver(
      readCurrent: () {
        final s = _mushafCubit.state;
        final playing = _playbackCubit.state.currentAyah;
        final playingHere =
            playing != null && _mushafCubit.playingPage == s.currentPage;
        final stored = _lastReadCubit.state;
        return LastRead(
          page: s.currentPage,
          ayah:
              s.selectedAyah ??
              (playingHere ? playing : null) ??
              (stored?.page == s.currentPage ? stored?.ayah : null),
        );
      },
      persist: (v) => _lastReadCubit.save(v).catchError((_) {}),
      origin: widget.args.origin,
    );
    WidgetsBinding.instance.addObserver(this);
    _pageSub = _mushafCubit.stream.map((s) => s.currentPage).distinct().listen((
      _,
    ) {
      if (mounted) _lastReadSaver.schedule();
    });
  }

  // Runs before the first build and whenever an InheritedWidget dependency
  // (like MediaQuery) changes — i.e. on orientation change.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    // Use available width (after safe-area insets) so the offset arithmetic
    // matches the actual item heights rendered by the ListView.
    final mq = MediaQuery.of(context);
    final availableWidth = mq.size.width - mq.padding.left - mq.padding.right;
    final newPageHeight = availableWidth / mushafPageAspect;

    if (newPageHeight == _scrollPageHeight) return; // no change

    final currentPage = _scrollPageHeight == 0
        ? widget
              .args
              .page // first call — use the navigation target
        : _mushafCubit
              .state
              .currentPage; // orientation flip — stay on current page

    _scrollPageHeight = newPageHeight;

    // Swap the controller so the new ListView attaches at the correct offset
    // from its very first frame — no post-frame jumpTo needed.
    final old = _scrollController;
    old.removeListener(_onScroll);
    _scrollController = ScrollController(
      initialScrollOffset: _scrollOffsetFor(currentPage),
    )..addListener(_onScroll);

    // Dispose the old controller after the next frame, by which time the
    // ListView will have detached from it and attached to the new one.
    WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _lastReadSaver.flush();
      _lastReadSaver.pause();
    } else if (state == AppLifecycleState.resumed) {
      _lastReadSaver.resume();
    }
  }

  @override
  void dispose() {
    _pageController.removeListener(_precacheFromPageController);
    _pageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    _lastReadSaver.flush();
    _lastReadSaver.dispose();
    _pageSub?.cancel();
    _resumeSub.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _scrollOffsetFor(int page) =>
      ((page - 1) * (_scrollPageHeight + _scrollPageGap)).clamp(
        0.0,
        double.infinity,
      );

  // ── Scroll-mode listener ───────────────────────────────────────────────────

  void _onScroll() {
    if (_scrollPageHeight == 0) return;
    final raw = _scrollController.offset / (_scrollPageHeight + _scrollPageGap);
    final page = (raw.round() + 1).clamp(1, 604);
    if (page != _mushafCubit.state.currentPage) {
      _setPageFromView(page);
      _precacheAround(page);
    }
  }

  void _setPageFromView(int page) {
    final manual = _turns.isManual(page);
    if (manual) _lastReadSaver.onManualTurn();
    _mushafCubit.setPage(page, byUser: manual);
  }

  // ── Page-mode listener ────────────────────────────────────────────────────

  void _precacheFromPageController() {
    final idx = _pageController.page?.round();
    if (idx == null) return;
    _precacheAround(idx + 1);
  }

  // ── Shared ─────────────────────────────────────────────────────────────────

  void _precacheAround(int page) {
    for (final n in [page - 1, page + 1]) {
      if (n < 1 || n > 604) continue;
      precacheImage(
        AssetImage(
          'assets/mushaf/pages/page_${n.toString().padLeft(3, '0')}.png',
        ),
        context,
      );
    }
  }

  void _onFollowChanged(MushafState state) {
    final target = nextFollowAction(
      followPlayback: state.followPlayback,
      currentPage: state.currentPage,
      playingPage: _mushafCubit.playingPage,
    );
    if (target == null) return;
    if (_effectiveMode(context) == MushafReadingMode.page) {
      if (!_pageController.hasClients) return;
      final turn = _turns.begin(target);
      _pageController
          .animateToPage(
            target - 1,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeInOut,
          )
          .whenComplete(() => _turns.end(turn));
    } else {
      if (!_scrollController.hasClients || _scrollPageHeight == 0) return;
      final turn = _turns.begin(target);
      _scrollController
          .animateTo(
            _scrollOffsetFor(target),
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeInOut,
          )
          .whenComplete(() => _turns.end(turn));
    }
  }

  // Landscape always forces scroll mode regardless of the persisted setting.
  MushafReadingMode _effectiveMode(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) return MushafReadingMode.scroll;
    return context.read<SettingsCubit>().state.settingsModel.readingMode;
  }

  void _play(AyahIdentifier start, AyahIdentifier end) {
    _mushafCubit.followFrom(start);
    _playbackCubit.playRange(start: start, end: end);
    _mushafCubit.clearSelection();
  }

  void _onPlayPage() {
    final range = pagePlaybackRange(_mushafCubit.state.pageAyahs);
    if (range != null) _play(range.start, range.end);
  }

  void _onListen() {
    final state = _mushafCubit.state;
    final range = listenRange(
      selected: state.selectedAyah,
      ayahs: state.pageAyahs,
    );
    if (range != null) _play(range.start, range.end);
  }

  void _onListenFromSurahStart(AyahIdentifier ayah) {
    final surah = ayah.surah;
    _play(
      AyahIdentifier(surah: surah, ayah: 1),
      AyahIdentifier(surah: surah, ayah: quran.getVerseCount(surah)),
    );
  }

  void _turnBy(int delta) {
    final page = _mushafCubit.state.currentPage;
    if (_effectiveMode(context) == MushafReadingMode.page) {
      if (!_pageController.hasClients) return;
      _pageController.animateToPage(
        page - 1 + delta,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    } else {
      if (!_scrollController.hasClients || _scrollPageHeight == 0) return;
      _scrollController.animateTo(
        _scrollOffsetFor(page + delta),
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _openMenu() async {
    final state = _mushafCubit.state;
    final action = await MenuSheet.show(
      context,
      currentSurah: state.runningSurah,
      currentJuz: sl<QuranMetaService>().getPageMeta(state.currentPage).juz,
    );
    if (!mounted) return;
    switch (action) {
      case MenuJump(:final page):
        _jumpInPlace(page);
      case MenuOpenPlaces():
        context.push(AppRouter.bookmarksPath);
      case MenuOpenDisplay():
        DisplaySheet.show(context);
      case MenuPlayPage():
        _onPlayPage();
      case null:
        break;
    }
  }

  void _jumpInPlace(int page) {
    _lastReadSaver.rearm();
    final turn = _turns.begin(page);
    _mushafCubit.jumpTo(page);
    if (_effectiveMode(context) == MushafReadingMode.page) {
      if (_pageController.hasClients) _pageController.jumpToPage(page - 1);
    } else {
      if (_scrollController.hasClients && _scrollPageHeight != 0) {
        _scrollController.jumpTo(_scrollOffsetFor(page));
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) => _turns.end(turn));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final settings = context.watch<SettingsCubit>().state.settingsModel;
    final effectiveMode = isLandscape
        ? MushafReadingMode.scroll
        : settings.readingMode;
    final colors = settings.mushafPaper.colors;

    return _LeafPopScope(
      onClose: _mushafCubit.clearSelection,
      child: BlocListener<MushafCubit, MushafState>(
        listenWhen: (a, b) =>
            a.playingAyah != b.playingAyah ||
            (!a.followPlayback && b.followPlayback),
        listener: (_, state) => _onFollowChanged(state),
        child: Scaffold(
          backgroundColor: colors.background,
          body: SafeArea(
            child: Column(
              children: [
                BlocSelector<MushafCubit, MushafState, (int, int?)>(
                  selector: (s) => (s.currentPage, s.runningSurah),
                  builder: (context, head) {
                    final (page, surah) = head;
                    final meta = sl<QuranMetaService>().getPageMeta(page);
                    return RunningHead(
                      surahName: surah == null
                          ? ''
                          : surahDisplayName(context, surah),
                      page: page,
                      juz: meta.juz,
                      hizb: meta.hizb,
                      colors: colors,
                      onBack: () => Navigator.of(context).pop(),
                      onOpenMenu: _openMenu,
                    );
                  },
                ),
                Expanded(
                  child: Stack(
                    children: [
                      Positioned.fill(
                        child: _buildReadingArea(context, effectiveMode),
                      ),
                      PositionedDirectional(
                        start: 0,
                        end: 0,
                        bottom: 0,
                        child: _LeafSlot(
                          colors: colors,
                          onListenFromHere: _onListen,
                          onListenFromSurahStart: _onListenFromSurahStart,
                          onListenPage: _onPlayPage,
                        ),
                      ),
                    ],
                  ),
                ),
                BlocBuilder<MushafCubit, MushafState>(
                  buildWhen: (a, b) =>
                      a.currentPage != b.currentPage ||
                      a.selectedAyah != b.selectedAyah ||
                      a.pageAyahs != b.pageAyahs,
                  builder: (context, state) => ReaderFoot(
                    colors: colors,
                    onPrevious: state.currentPage > 1
                        ? () => _turnBy(-1)
                        : null,
                    onNext: state.currentPage < 604 ? () => _turnBy(1) : null,
                    onListen:
                        listenRange(
                              selected: state.selectedAyah,
                              ayahs: state.pageAyahs,
                            ) ==
                            null
                        ? null
                        : _onListen,
                    onMenu: _openMenu,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildReadingArea(BuildContext context, MushafReadingMode mode) {
    final modeChanged = _lastBuiltMode != mode;
    _lastBuiltMode = mode;

    if (mode == MushafReadingMode.scroll) {
      // On a real mode switch (page → scroll), sync the scroll controller to
      // wherever the user currently is. Unrelated rebuilds (brightness change,
      // paper theme, etc.) skip this so we never interrupt the user's scroll.
      if (modeChanged) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted ||
              !_scrollController.hasClients ||
              _scrollPageHeight == 0) {
            return;
          }
          final page = _mushafCubit.state.currentPage;
          final turn = _turns.begin(page);
          _scrollController.jumpTo(_scrollOffsetFor(page));
          WidgetsBinding.instance.addPostFrameCallback((_) => _turns.end(turn));
        });
      }

      final separatorColor = context
          .read<SettingsCubit>()
          .state
          .settingsModel
          .mushafPaper
          .colors
          .accent
          .withValues(alpha: 0.35);

      return ColoredBox(
        color: separatorColor,
        child: ListView.builder(
          controller: _scrollController,
          itemCount: 604,
          itemExtent: _scrollPageHeight + _scrollPageGap,
          itemBuilder: (_, i) => Padding(
            padding: const EdgeInsets.only(bottom: _scrollPageGap),
            child: MushafPageView(pageNumber: i + 1),
          ),
        ),
      );
    }

    // Page mode — on a real mode switch (scroll → page) the PageController
    // may still point to where it was before scroll mode started; correct it.
    if (modeChanged) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_pageController.hasClients) return;
        final page = _mushafCubit.state.currentPage;
        final turn = _turns.begin(page);
        _pageController.jumpToPage(page - 1);
        WidgetsBinding.instance.addPostFrameCallback((_) => _turns.end(turn));
      });
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PageView.builder(
        controller: _pageController,
        itemCount: 604,
        onPageChanged: (i) => _setPageFromView(i + 1),
        itemBuilder: (_, i) => Center(child: MushafPageView(pageNumber: i + 1)),
      ),
    );
  }
}

class _LeafPopScope extends StatelessWidget {
  const _LeafPopScope({required this.onClose, required this.child});

  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<MushafCubit, MushafState, bool>(
        selector: (s) => s.selectedAyah == null,
        builder: (context, noLeaf) => PopScope(
          canPop: noLeaf,
          onPopInvokedWithResult: (didPop, _) {
            if (!didPop) onClose();
          },
          child: child,
        ),
      );
}

class _LeafSlot extends StatelessWidget {
  const _LeafSlot({
    required this.colors,
    required this.onListenFromHere,
    required this.onListenFromSurahStart,
    required this.onListenPage,
  });

  final MushafPaperColors colors;
  final VoidCallback onListenFromHere;
  final void Function(AyahIdentifier ayah) onListenFromSurahStart;
  final VoidCallback onListenPage;

  @override
  Widget build(BuildContext context) {
    final mushaf = context.read<MushafCubit>();
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      child: BlocSelector<MushafCubit, MushafState, AyahIdentifier?>(
        selector: (s) => s.selectedAyah,
        builder: (context, selected) =>
            BlocSelector<PlaybackCubit, PlaybackState, bool>(
              selector: (p) => (p.requestedAyah ?? p.currentAyah) != null,
              builder: (context, active) => AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: selected != null
                    ? AyahLeaf(
                        key: ValueKey(selected),
                        ayah: selected,
                        colors: colors,
                        onClose: mushaf.clearSelection,
                        onListenFromHere: onListenFromHere,
                        onListenFromSurahStart: () =>
                            onListenFromSurahStart(selected),
                        onListenPage: onListenPage,
                      )
                    : active
                    ? BlocBuilder<MushafCubit, MushafState>(
                        key: const ValueKey('player'),
                        buildWhen: (a, b) =>
                            a.followPlayback != b.followPlayback ||
                            a.playingAyah != b.playingAyah,
                        builder: (context, state) {
                          final playing = state.playingAyah;
                          final page = mushaf.playingPage;
                          return PlayerLeaf(
                            colors: colors,
                            away:
                                !state.followPlayback &&
                                    playing != null &&
                                    page != null
                                ? (ayah: playing, page: page)
                                : null,
                            onReturnToPlaying: mushaf.resumeFollow,
                            onNewPlay: mushaf.resumeFollow,
                          );
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
      ),
    );
  }
}
