import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/constants/mushaf_reading_mode.dart';
import '../../utils/mushaf_paper_colors.dart';
import '../../../../../core/di/dependency_injection.dart';
import '../../../../quran_playback/domain/services/quran_page_service.dart';
import '../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../domain/entities/last_read.dart';
import '../../cubit/last_read/last_read_cubit.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';
import '../../cubit/mushaf/mushaf_state.dart';
import 'auto_swap_helper.dart';
import 'widgets/ayah_playback_overlay.dart';
import 'widgets/mushaf_action_dock.dart';
import 'widgets/mushaf_page_view.dart';

class MushafPage extends StatefulWidget {
  const MushafPage({super.key, required this.initialPage});
  final int initialPage;

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  late final PageController _pageController;

  // Not `final` — recreated in didChangeDependencies when the screen width
  // changes (orientation flip) so the scroll position is always initialised
  // to the correct page BEFORE the first paint. This eliminates the one-frame
  // flash of page 1 that a post-frame jumpTo would cause.
  late ScrollController _scrollController;

  late final MushafCubit _mushafCubit;
  late final PlaybackCubit _playbackCubit;
  late final LastReadCubit _lastReadCubit;

  // Gap between pages in scroll mode (logical pixels).
  static const double _scrollPageGap = 4.0;

  // Tracks which mode was rendered last so _buildReadingArea can detect a
  // real mode switch vs. a rebuild caused by an unrelated settings change.
  MushafReadingMode? _lastBuiltMode;

  // Height of one Mushaf page in scroll mode. Derived from the available
  // width × the fixed 1:1.82 aspect ratio. Updated in didChangeDependencies.
  double _scrollPageHeight = 0.0;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage - 1);
    _pageController.addListener(_precacheFromPageController);

    // Placeholder — replaced with the correctly-offset controller in
    // didChangeDependencies, which runs before the first build.
    _scrollController = ScrollController();

    _mushafCubit = context.read<MushafCubit>();
    _playbackCubit = context.read<PlaybackCubit>();
    _lastReadCubit = context.read<LastReadCubit>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (_mushafCubit.state.highlightedAyah != null) return;
      final last = _lastReadCubit.state;
      if (last?.ayah == null) return;
      if (last!.page != widget.initialPage) return;
      _mushafCubit.toggleHighlight(last.ayah!);
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
    final availableWidth =
        mq.size.width - mq.padding.left - mq.padding.right;
    final newPageHeight = availableWidth * 1.82;

    if (newPageHeight == _scrollPageHeight) return; // no change

    final currentPage = _scrollPageHeight == 0
        ? widget.initialPage // first call — use the navigation target
        : _mushafCubit.state.currentPage; // orientation flip — stay on current page

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
  void dispose() {
    _pageController.removeListener(_precacheFromPageController);
    _pageController.dispose();
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();

    // Release any orientation lock set by the rotate button so the rest of
    // the app is free to follow the sensor again.
    SystemChrome.setPreferredOrientations([]);

    final mushafState = _mushafCubit.state;
    final ayah =
        mushafState.highlightedAyah ?? _playbackCubit.state.currentAyah;
    _lastReadCubit
        .save(LastRead(page: mushafState.currentPage, ayah: ayah))
        .catchError((_) {});
    _playbackCubit.stop();

    super.dispose();
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  double _scrollOffsetFor(int page) =>
      ((page - 1) * (_scrollPageHeight + _scrollPageGap))
          .clamp(0.0, double.infinity);

  // ── Scroll-mode listener ───────────────────────────────────────────────────

  void _onScroll() {
    if (_scrollPageHeight == 0) return;
    final raw =
        _scrollController.offset / (_scrollPageHeight + _scrollPageGap);
    final page = (raw.round() + 1).clamp(1, 604);
    if (page != _mushafCubit.state.currentPage) {
      _mushafCubit.setPage(page);
      _precacheAround(page);
    }
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
            'assets/mushaf/pages/page_${n.toString().padLeft(3, '0')}.png'),
        context,
      );
    }
  }

  void _onPlayingAyahChanged(MushafState state) {
    final effectiveMode = _effectiveMode(context);
    if (effectiveMode == MushafReadingMode.page) {
      if (!_pageController.hasClients) return;
      final targetIdx = computeAutoSwapTargetIndex(
        playingAyah: state.playingAyah,
        currentPageIndex: _pageController.page?.round(),
        pageService: sl<QuranPageService>(),
      );
      if (targetIdx == null) return;
      _pageController.animateToPage(
        targetIdx,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      if (!_scrollController.hasClients || _scrollPageHeight == 0) return;
      final targetIdx = computeAutoSwapTargetIndex(
        playingAyah: state.playingAyah,
        currentPageIndex: _mushafCubit.state.currentPage - 1,
        pageService: sl<QuranPageService>(),
      );
      if (targetIdx == null) return;
      _scrollController.animateTo(
        _scrollOffsetFor(targetIdx + 1),
        duration: const Duration(milliseconds: 400),
        curve: Curves.easeInOut,
      );
    }
  }

  // Landscape always forces scroll mode regardless of the persisted setting.
  MushafReadingMode _effectiveMode(BuildContext context) {
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    if (isLandscape) return MushafReadingMode.scroll;
    return context.read<SettingsCubit>().state.settingsModel.readingMode;
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    // Reading mode: landscape always uses scroll; portrait respects settings.
    final isLandscape =
        MediaQuery.of(context).orientation == Orientation.landscape;
    final readingMode =
        context.watch<SettingsCubit>().state.settingsModel.readingMode;
    final effectiveMode =
        isLandscape ? MushafReadingMode.scroll : readingMode;

    return BlocListener<MushafCubit, MushafState>(
      listenWhen: (a, b) => a.playingAyah != b.playingAyah,
      listener: (_, state) => _onPlayingAyahChanged(state),
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              // Reading area.
              Positioned.fill(
                child: _buildReadingArea(context, effectiveMode),
              ),

              // Floating action dock — lifts above the mini-player when visible.
              BlocBuilder<MushafCubit, MushafState>(
                buildWhen: (a, b) =>
                    a.chromeVisible != b.chromeVisible ||
                    a.highlightedAyah != b.highlightedAyah ||
                    a.isOverlayPinned != b.isOverlayPinned,
                builder: (context, state) {
                  final miniPlayerVisible =
                      state.highlightedAyah != null || state.isOverlayPinned;
                  return SafeArea(
                    child: Align(
                      alignment: Alignment.bottomCenter,
                      child: AnimatedSlide(
                        offset: state.chromeVisible
                            ? Offset.zero
                            : const Offset(0, 2),
                        duration: const Duration(milliseconds: 220),
                        curve: Curves.easeOutCubic,
                        child: AnimatedOpacity(
                          opacity: state.chromeVisible ? 1 : 0,
                          duration: const Duration(milliseconds: 180),
                          child: IgnorePointer(
                            ignoring: !state.chromeVisible,
                            child: AnimatedPadding(
                              duration: const Duration(milliseconds: 280),
                              curve: Curves.easeOutCubic,
                              padding: EdgeInsets.only(
                                bottom: miniPlayerVisible ? 76.0 : 16.0,
                              ),
                              child: const MushafActionDock(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                },
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
          _scrollController
              .jumpTo(_scrollOffsetFor(_mushafCubit.state.currentPage));
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
        _pageController.jumpToPage(_mushafCubit.state.currentPage - 1);
      });
    }
    return Directionality(
      textDirection: TextDirection.rtl,
      child: PageView.builder(
        controller: _pageController,
        itemCount: 604,
        onPageChanged: (i) => _mushafCubit.setPage(i + 1),
        itemBuilder: (_, i) => MushafPageView(pageNumber: i + 1),
      ),
    );
  }
}
