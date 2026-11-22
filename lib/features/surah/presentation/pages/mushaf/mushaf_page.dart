import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quran/quran.dart' as quran;

import '../../../../../config/router/app_router.dart';
import '../../../../../config/router/now_playing_route.dart';
import '../../../../../core/constants/mushaf_reading_mode.dart';
import '../../../../../core/di/dependency_injection.dart';
import '../../../../../core/utils/screen_wake.dart';
import '../../../../../core/helper functions/locale_helpers.dart';
import '../../../../../core/localization/pending_s.dart';
import '../../utils/mushaf_paper_colors.dart';
import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../quran_playback/domain/services/quran_meta_service.dart';
import '../../../../quran_playback/domain/services/quran_page_service.dart';
import '../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../../quran_playback/presentation/cubit/playback/playback_state.dart';
import '../../../../quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart';
import '../../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../domain/entities/ayah_bound_entity.dart';
import '../../../domain/entities/last_read.dart';
import '../../../domain/usecases/get_mushaf_page.dart';
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
import 'widgets/notice_chip.dart';
import 'widgets/player_leaf.dart';
import 'widgets/reader_foot.dart';
import 'widgets/running_head.dart';

class MushafPage extends StatefulWidget {
  const MushafPage({
    super.key,
    required this.args,
    this.screenWake = const ScreenWake(),
  });
  final MushafArgs args;
  final ScreenWake screenWake;

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
  late final SettingsCubit _settingsCubit;
  final _overlayHeight = ValueNotifier(0.0);

  late final LastReadSaver _lastReadSaver;
  final _turns = PageTurnTracker();
  StreamSubscription<int>? _pageSub;
  late final StreamSubscription<void> _resumeSub;
  late final StreamSubscription<PlaybackState> _playbackSub;

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
    _settingsCubit = context.read<SettingsCubit>();
    if (_settingsCubit.state.settingsModel.keepScreenOn) {
      widget.screenWake.set(true);
    }
    _resumeSub = nowPlayingResume.stream.listen(
      (_) => _mushafCubit.resumeFollow(),
    );

    _playbackSub = _playbackCubit.stream
        .where((s) => !s.isLoading && !s.isPlaying)
        .listen((_) => _mushafCubit.cancelFollowTarget());

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
    _playbackSub.cancel();
    _overlayHeight.dispose();
    widget.screenWake.set(false);
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

  void _followNewPlay() {
    final next = _playbackCubit.state.requestedAyah;
    if (next == null) {
      _mushafCubit.resumeFollow();
    } else {
      _mushafCubit.followFrom(next);
    }
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

  void _onOverlayMeasured(Size size) {
    if (!mounted) return;
    _overlayHeight.value = size.height;
    final selected = _mushafCubit.state.selectedAyah;
    if (selected != null &&
        _effectiveMode(context) == MushafReadingMode.scroll) {
      _slideScrollTo(selected);
    }
  }

  Future<void> _slideScrollTo(AyahIdentifier ayah) async {
    final page = sl<QuranPageService>().getPageForAyah(
      ayah.surah,
      ayah.realAyah,
    );
    final state = _mushafCubit.state;
    final bounds = page == state.currentPage && state.pageAyahs.isNotEmpty
        ? state.pageAyahs
        : (await sl<GetMushafPage>()(
            page,
          )).fold((_) => const <AyahBoundEntity>[], (e) => e.ayahs);
    final lineBottom = lineBottomOf(bounds, ayah);
    if (!mounted ||
        lineBottom == null ||
        !_scrollController.hasClients ||
        _mushafCubit.state.selectedAyah != ayah) {
      return;
    }
    final position = _scrollController.position;
    final bottom =
        _scrollOffsetFor(page) -
        position.pixels +
        lineBottom * _scrollPageHeight;
    final need = bottom - (position.viewportDimension - _overlayHeight.value);
    if (need <= 0) return;
    final turn = _turns.begin(_mushafCubit.state.currentPage);
    _scrollController
        .animateTo(
          position.pixels + need,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeInOut,
        )
        .whenComplete(() => _turns.end(turn));
  }

  void _downloadPlaying(int surah) {
    context.read<SurahDownloadCubit>().download(
      _playbackCubit.state.reciter,
      surah,
    );
    _settingsCubit.markDownloadHintSeen();
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
    final (readingMode, paper) = context.select(
      (SettingsCubit c) => (
        c.state.settingsModel.readingMode,
        c.state.settingsModel.mushafPaper,
      ),
    );
    final effectiveMode = isLandscape ? MushafReadingMode.scroll : readingMode;
    final colors = paper.colors;

    return _LeafPopScope(
      onClose: _mushafCubit.clearSelection,
      child: MultiBlocListener(
        listeners: [
          BlocListener<MushafCubit, MushafState>(
            listenWhen: (a, b) =>
                a.playingAyah != b.playingAyah ||
                (!a.followPlayback && b.followPlayback),
            listener: (_, state) => _onFollowChanged(state),
          ),
          BlocListener<MushafCubit, MushafState>(
            listenWhen: (a, b) =>
                a.selectedAyah == null && b.selectedAyah != null,
            listener: (_, _) => _settingsCubit.markHintSeen(),
          ),
          BlocListener<MushafCubit, MushafState>(
            listenWhen: (a, b) =>
                b.selectedAyah != null && a.selectedAyah != b.selectedAyah,
            listener: (context, state) {
              if (_effectiveMode(context) == MushafReadingMode.scroll) {
                _slideScrollTo(state.selectedAyah!);
              }
            },
          ),
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (a, b) =>
                a.settingsModel.keepScreenOn != b.settingsModel.keepScreenOn,
            listener: (_, state) =>
                widget.screenWake.set(state.settingsModel.keepScreenOn),
          ),
        ],
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
                  child: LayoutBuilder(
                    builder: (context, constraints) => Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRect(
                            child: _buildReadingArea(
                              context,
                              effectiveMode,
                              constraints.biggest,
                            ),
                          ),
                        ),
                        PositionedDirectional(
                          start: 0,
                          end: 0,
                          bottom: 0,
                          child: _MeasuredSize(
                            onChange: _onOverlayMeasured,
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _NoticeSlot(
                                  colors: colors,
                                  onReturn: _jumpInPlace,
                                  onDownload: _downloadPlaying,
                                ),
                                _LeafSlot(
                                  colors: colors,
                                  onListenFromHere: _onListen,
                                  onNewPlay: _followNewPlay,
                                  onListenFromSurahStart:
                                      _onListenFromSurahStart,
                                  onListenPage: _onPlayPage,
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
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

  Widget _buildReadingArea(
    BuildContext context,
    MushafReadingMode mode,
    Size area,
  ) {
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
    return _PageSlide(
      area: area,
      overlayHeight: _overlayHeight,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: PageView.builder(
          controller: _pageController,
          itemCount: 604,
          onPageChanged: (i) => _setPageFromView(i + 1),
          itemBuilder: (_, i) =>
              Center(child: MushafPageView(pageNumber: i + 1)),
        ),
      ),
    );
  }
}

class _MeasuredSize extends SingleChildRenderObjectWidget {
  const _MeasuredSize({required this.onChange, super.child});

  final ValueChanged<Size> onChange;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderMeasuredSize(onChange);

  @override
  void updateRenderObject(
    BuildContext context,
    covariant _RenderMeasuredSize renderObject,
  ) => renderObject.onChange = onChange;
}

class _RenderMeasuredSize extends RenderProxyBox {
  _RenderMeasuredSize(this.onChange);

  ValueChanged<Size> onChange;
  Size? _reported;

  @override
  void performLayout() {
    super.performLayout();
    final measured = size;
    if (measured == _reported) return;
    _reported = measured;
    WidgetsBinding.instance.addPostFrameCallback((_) => onChange(measured));
  }
}

class _PageSlide extends StatelessWidget {
  const _PageSlide({
    required this.area,
    required this.overlayHeight,
    required this.child,
  });

  final Size area;
  final ValueNotifier<double> overlayHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<double>(
    valueListenable: overlayHeight,
    child: child,
    builder: (context, overlay, child) =>
        BlocSelector<MushafCubit, MushafState, double?>(
          selector: (s) => lineBottomOf(s.pageAyahs, s.selectedAyah),
          builder: (context, lineBottom) => TweenAnimationBuilder<double>(
            tween: Tween(
              end: lineBottom == null
                  ? 0
                  : leafSlide(
                      area: area,
                      lineBottom: lineBottom,
                      overlay: overlay,
                    ),
            ),
            duration: const Duration(milliseconds: 200),
            child: child,
            builder: (context, slide, child) => Transform.translate(
              key: const ValueKey('page-slide'),
              offset: Offset(0, -slide),
              child: child,
            ),
          ),
        ),
  );
}

class _NoticeSlot extends StatelessWidget {
  const _NoticeSlot({
    required this.colors,
    required this.onReturn,
    required this.onDownload,
  });

  final MushafPaperColors colors;
  final void Function(int page) onReturn;
  final void Function(int surah) onDownload;

  @override
  Widget build(BuildContext context) {
    final pending = PendingS.of(context);
    final settings = context.read<SettingsCubit>();
    final jumpFrom = context.select((MushafCubit c) => c.state.jumpFrom);
    final (hintSeen, downloadHintSeen) = context.select(
      (SettingsCubit c) => (
        c.state.settingsModel.hintSeen,
        c.state.settingsModel.downloadHintSeen,
      ),
    );
    final (downloadSurah, audioError) = context.select(
      (PlaybackCubit c) => (
        c.state.playedFromNetwork && !downloadHintSeen
            ? c.state.skipOrigin?.surah
            : null,
        c.state.error != null,
      ),
    );
    final notice = readerNotice(
      jumpFrom: jumpFrom,
      downloadHintSurah: downloadSurah,
      hintSeen: hintSeen,
      audioError: audioError,
    );
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: switch (notice) {
        null => const SizedBox.shrink(key: ValueKey('no-notice')),
        final notice => Padding(
          key: ValueKey(notice),
          padding: const EdgeInsets.only(bottom: 8),
          child: Center(
            child: switch (notice) {
              ReturnToPageNotice(:final page) => NoticeChip(
                label: pending.notice_returnToPage(page.toLocalized(context)),
                colors: colors,
                onTap: () => onReturn(page),
              ),
              DownloadHintNotice(:final surah) => NoticeChip(
                label: pending.surahDownload_hint,
                colors: colors,
                onTap: () => onDownload(surah),
                actionLabel: pending.notice_gotIt,
                onAction: settings.markDownloadHintSeen,
              ),
              TapHintNotice() => NoticeChip(
                label: pending.notice_tapHint,
                colors: colors,
                onTap: settings.markHintSeen,
                actionLabel: pending.notice_gotIt,
                onAction: settings.markHintSeen,
              ),
            },
          ),
        ),
      },
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
    required this.onNewPlay,
  });

  final MushafPaperColors colors;
  final VoidCallback onListenFromHere;
  final void Function(AyahIdentifier ayah) onListenFromSurahStart;
  final VoidCallback onListenPage;
  final VoidCallback onNewPlay;

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
                            onNewPlay: onNewPlay,
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
