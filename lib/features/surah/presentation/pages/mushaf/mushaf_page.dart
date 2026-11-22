import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../config/router/now_playing_route.dart';
import '../../../../../core/constants/mushaf_reading_mode.dart';
import '../../../../../core/helper functions/locale_helpers.dart';
import '../../utils/mushaf_paper_colors.dart';
import '../../../../bookmarks/presentation/cubit/page_bookmark_cubit.dart';
import '../../../../bookmarks/presentation/cubit/page_bookmark_state.dart';
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
import 'widgets/ayah_playback_overlay.dart';
import 'widgets/mushaf_browse_bar.dart';
import 'widgets/mushaf_page_view.dart';
import 'widgets/mushaf_top_bar.dart';
import 'widgets/page_jump_sheet.dart';
import 'widgets/display_sheet.dart';

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

  void _onPlayPage() {
    final range = pagePlaybackRange(_mushafCubit.state.pageAyahs);
    if (range == null) return;
    _mushafCubit.resumeFollow();
    _playbackCubit.playRange(start: range.start, end: range.end);
  }

  Future<void> _onJumpToPage(BuildContext context) async {
    final page = await PageJumpSheet.show(context);
    if (page == null || !context.mounted) return;
    _lastReadSaver.rearm();
    final turn = _turns.begin(page);
    if (_effectiveMode(context) == MushafReadingMode.page) {
      if (_pageController.hasClients) _pageController.jumpToPage(page - 1);
    } else {
      if (_scrollController.hasClients && _scrollPageHeight != 0) {
        _scrollController.jumpTo(_scrollOffsetFor(page));
      }
    }
    _mushafCubit.setPage(page, byUser: true);
    WidgetsBinding.instance.addPostFrameCallback((_) => _turns.end(turn));
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Reading mode: landscape always uses scroll; portrait respects settings.
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final readingMode = context
        .watch<SettingsCubit>()
        .state
        .settingsModel
        .readingMode;
    final effectiveMode = isLandscape ? MushafReadingMode.scroll : readingMode;

    return BlocListener<MushafCubit, MushafState>(
      listenWhen: (a, b) =>
          a.playingAyah != b.playingAyah ||
          (!a.followPlayback && b.followPlayback),
      listener: (_, state) => _onFollowChanged(state),
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // Reading area.
              Positioned.fill(child: _buildReadingArea(context, effectiveMode)),

              // Top bar — visible whenever chrome is visible (even during
              // playback, so back / page-jump stay reachable).
              BlocBuilder<MushafCubit, MushafState>(
                buildWhen: (a, b) =>
                    a.chromeVisible != b.chromeVisible ||
                    a.currentPage != b.currentPage ||
                    a.selectedAyah != b.selectedAyah ||
                    a.playingAyah != b.playingAyah ||
                    a.pageAyahs != b.pageAyahs ||
                    a.openedSurah != b.openedSurah,
                builder: (context, state) {
                  final running = state.runningSurah;
                  return SafeArea(
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: AnimatedSlide(
                        offset: state.chromeVisible
                            ? Offset.zero
                            : const Offset(0, -2),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: state.chromeVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: IgnorePointer(
                            ignoring: !state.chromeVisible,
                            child: Padding(
                              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
                              child: MushafTopBar(
                                surahName: running == null
                                    ? ''
                                    : surahDisplayName(context, running),
                                pageNumber: state.currentPage,
                                localeCode: context.langCode,
                                onBack: () => Navigator.of(context).maybePop(),
                                onJump: () => _onJumpToPage(context),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

              // Browse bar — only when chrome is visible AND the player is not.
              BlocBuilder<MushafCubit, MushafState>(
                buildWhen: (a, b) =>
                    a.chromeVisible != b.chromeVisible ||
                    a.selectedAyah != b.selectedAyah ||
                    a.isOverlayPinned != b.isOverlayPinned ||
                    a.currentPage != b.currentPage,
                builder: (context, state) => _BrowseBarSlot(
                  chromeVisible: state.chromeVisible,
                  selectedOrPinned:
                      state.selectedAyah != null || state.isOverlayPinned,
                  currentPage: state.currentPage,
                  onPlay: _onPlayPage,
                ),
              ),

              const AyahPlaybackOverlay(),
            ],
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

class _BrowseBarSlot extends StatelessWidget {
  const _BrowseBarSlot({
    required this.chromeVisible,
    required this.selectedOrPinned,
    required this.currentPage,
    required this.onPlay,
  });

  final bool chromeVisible;
  final bool selectedOrPinned;
  final int currentPage;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<PlaybackCubit, PlaybackState, bool>(
      selector: (p) => (p.requestedAyah ?? p.currentAyah) != null,
      builder: (context, active) {
        final visible = chromeVisible && !(selectedOrPinned || active);
        return SafeArea(
          child: Align(
            alignment: Alignment.bottomCenter,
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, 2),
              duration: const Duration(milliseconds: 220),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: visible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: IgnorePointer(
                  ignoring: !visible,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: BlocBuilder<PageBookmarkCubit, PageBookmarkState>(
                      buildWhen: (a, b) =>
                          a.contains(currentPage) != b.contains(currentPage),
                      builder: (context, pb) => MushafBrowseBar(
                        isSaved: pb.contains(currentPage),
                        onSettings: () => DisplaySheet.show(context),
                        onPlay: onPlay,
                        onToggleSave: () => context
                            .read<PageBookmarkCubit>()
                            .toggle(currentPage),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
