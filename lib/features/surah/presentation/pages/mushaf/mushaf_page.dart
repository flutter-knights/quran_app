import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:quran/quran.dart' as quran;

import '../../../../../config/router/now_playing_route.dart';
import '../../../../../core/constants/leaf_tap_action.dart';
import '../../../../../core/constants/mushaf_reading_mode.dart';
import '../../../../../core/di/dependency_injection.dart';
import '../../../../../core/helper functions/locale_helpers.dart';
import '../../../../../core/localization/pending_s.dart';
import '../../../../../core/utils/screen_wake.dart';
import '../../../../bookmarks/domain/entities/fasil_slot.dart';
import '../../../../bookmarks/presentation/cubit/fasil_cubit.dart';
import '../../../../bookmarks/presentation/pages/widgets/places_sheet.dart';
import '../../../../bookmarks/presentation/utils/fasil_rules.dart';
import '../../../../bookmarks/presentation/utils/place_labels.dart';
import '../../../../bookmarks/presentation/utils/place_notices.dart';
import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../quran_playback/domain/services/quran_meta_service.dart';
import '../../../../quran_playback/domain/services/quran_page_service.dart';
import '../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../../quran_playback/presentation/cubit/playback/playback_state.dart';
import '../../../../quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart';
import '../../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../../tafsir/presentation/cubit/tafsir_cubit.dart';
import '../../../domain/entities/ayah_bound_entity.dart';
import '../../../domain/entities/last_read.dart';
import '../../cubit/last_read/last_read_cubit.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';
import '../../cubit/mushaf/mushaf_state.dart';
import '../../utils/follow_playback.dart';
import '../../utils/mushaf_args.dart';
import '../../utils/mushaf_paper_colors.dart';
import '../../utils/page_bounds.dart';
import '../../utils/reader_rules.dart';
import 'last_read_saver.dart';
import 'page_turn_tracker.dart';
import 'widgets/ayah_leaf.dart';
import 'widgets/ayah_study_leaf.dart';
import 'widgets/display_sheet.dart';
import 'widgets/fasil_chooser.dart';
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
  late final TafsirCubit _tafsirCubit;
  final _studying = ValueNotifier(false);
  final _overlayHeight = ValueNotifier(0.0);
  final _chipHeight = ValueNotifier(0.0);
  AyahIdentifier? _slidFor;

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
  // width × the fixed 1:1.82 aspect ratio. Updated in didChangeDependencies.
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
    _tafsirCubit = context.read<TafsirCubit>();
    final initial = _mushafCubit.state.selectedAyah;
    if (initial != null) _tafsirCubit.load(initial);
    if (_settingsCubit.state.settingsModel.keepScreenOn) {
      widget.screenWake.hold(this, on: true);
    }
    if (widget.args.focusAyah != null) _settingsCubit.markHintSeen();
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
            playing != null &&
            sl<QuranPageService>().getPageForAyah(
                  playing.surah,
                  playing.realAyah,
                ) ==
                s.currentPage;
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
    _studying.dispose();
    _overlayHeight.dispose();
    _chipHeight.dispose();
    widget.screenWake.hold(this, on: false);
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
        final open = await PlacesSheet.show(context);
        if (!mounted || open == null) return;
        _jumpInPlace(open.page, focus: open.focus);
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
    final target = _slideTarget;
    if (target == null || size.height == 0) {
      _slidFor = null;
    } else if (target != _slidFor &&
        _effectiveMode(context) == MushafReadingMode.scroll) {
      _slidFor = target;
      _slideScrollTo(target);
    }
  }

  AyahIdentifier? get _slideTarget {
    final state = _mushafCubit.state;
    return state.selectedAyah ?? state.playingAyah;
  }

  Future<void> _slideScrollTo(AyahIdentifier ayah) async {
    final page = sl<QuranPageService>().getPageForAyah(
      ayah.surah,
      ayah.realAyah,
    );
    final state = _mushafCubit.state;
    if (_overlayHeight.value == 0 ||
        (state.selectedAyah == null && page != state.currentPage)) {
      return;
    }
    final bounds = await _mushafCubit.boundsFor(page);
    final lineBottom = lineBottomOf(bounds, ayah);
    if (!mounted ||
        lineBottom == null ||
        !_scrollController.hasClients ||
        _slideTarget != ayah) {
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

  Future<void> _openFawasil(FasilSlot? preselect) async {
    final fawasil = context.read<FasilCubit>();
    final state = _mushafCubit.state;
    final selected = (state.selectedAyah?.ayah ?? 0) > 0
        ? state.selectedAyah
        : null;
    final pre =
        preselect ??
        (selected == null
            ? null
            : chooserPreselect(
                slots: fawasil.state.slots,
                page: state.currentPage,
                at: selected,
              ));
    final choice = await FasilChooser.show(
      context,
      slots: fawasil.state.slots,
      selected: selected,
      preselect: pre,
    );
    if (!mounted) return;
    switch (choice) {
      case FasilGo(:final place):
        _jumpInPlace(place.page, focus: place.ayah);
      case FasilMoveHere(:final slot):
        await _moveFasil(fawasil, slot, selected!);
      case null:
        break;
    }
  }

  Future<void> _moveFasil(
    FasilCubit fawasil,
    FasilSlot slot,
    AyahIdentifier ayah,
  ) async {
    final result = await fawasil.move(slot, ayah);
    if (!mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    if (result == null) {
      if (fawasil.state.error != null) showPlaceWriteError(messenger);
      return;
    }
    final s = PendingS.current;
    final name = fasilName(context, slot, result.moved);
    final place = ayahPlace(context, ayah);
    showPlaceNotice(
      messenger,
      result.previous == null
          ? s.fasil_placed(name, place)
          : s.fasil_moved(name, place),
      onUndo: () => fawasil.restore(slot, result.previous),
    );
  }

  void _moveViewTo(int page) {
    if (_effectiveMode(context) == MushafReadingMode.page) {
      if (_pageController.hasClients) _pageController.jumpToPage(page - 1);
    } else {
      if (_scrollController.hasClients && _scrollPageHeight != 0) {
        _scrollController.jumpTo(_scrollOffsetFor(page));
      }
    }
  }

  void _jumpInPlace(int page, {AyahIdentifier? focus}) {
    _lastReadSaver.rearm();
    final turn = _turns.begin(page);
    _mushafCubit.jumpTo(page, focus: focus);
    _moveViewTo(page);
    WidgetsBinding.instance.addPostFrameCallback((_) => _turns.end(turn));
  }

  void _closeLeaf() {
    if (_studying.value) {
      _studying.value = false;
    } else {
      _mushafCubit.clearSelection();
    }
  }

  void _stepAyah(int delta) {
    final selected = _mushafCubit.state.selectedAyah;
    if (selected == null) return;
    final target = adjacentAyah(selected, delta);
    if (target == null) return;
    final page = sl<QuranPageService>().getPageForAyah(
      target.surah,
      target.ayah,
    );
    if (page == _mushafCubit.state.currentPage) {
      _mushafCubit.stepTo(target, page: page);
      return;
    }
    _lastReadSaver.onManualTurn();
    final turn = _turns.begin(page);
    _mushafCubit.stepTo(target, page: page);
    _moveViewTo(page);
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
      onClose: _closeLeaf,
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
            listenWhen: (a, b) => a.selectedAyah != b.selectedAyah,
            listener: (_, state) {
              final selected = state.selectedAyah;
              if (selected == null) {
                _studying.value = false;
                _tafsirCubit.cancel();
              } else {
                _tafsirCubit.load(selected);
              }
            },
          ),
          BlocListener<MushafCubit, MushafState>(
            listenWhen: (a, b) {
              final target = b.selectedAyah ?? b.playingAyah;
              return target != null &&
                  target != (a.selectedAyah ?? a.playingAyah);
            },
            listener: (context, state) {
              if (_effectiveMode(context) == MushafReadingMode.scroll) {
                final target = state.selectedAyah ?? state.playingAyah!;
                if (_slidFor != null) _slidFor = target;
                _slideScrollTo(target);
              }
            },
          ),
          BlocListener<SettingsCubit, SettingsState>(
            listenWhen: (a, b) =>
                a.settingsModel.keepScreenOn != b.settingsModel.keepScreenOn,
            listener: (_, state) => widget.screenWake.hold(
              this,
              on: state.settingsModel.keepScreenOn,
            ),
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
                      onBack: () => context.pop(),
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
                                if (effectiveMode == MushafReadingMode.page)
                                  _MeasuredSize(
                                    onChange: (size) =>
                                        _chipHeight.value = size.height,
                                    child: _NoticeSlot(
                                      colors: colors,
                                      onReturn: _jumpInPlace,
                                      onDownload: _downloadPlaying,
                                    ),
                                  ),
                                _LeafSlot(
                                  colors: colors,
                                  onListenFromHere: _onListen,
                                  onNewPlay: _followNewPlay,
                                  onListenFromSurahStart:
                                      _onListenFromSurahStart,
                                  onListenPage: _onPlayPage,
                                  onFasil: () => _openFawasil(null),
                                  studying: _studying,
                                  onExpand: () => _studying.value = true,
                                ),
                              ],
                            ),
                          ),
                        ),
                        Positioned.fill(
                          child: _StudyLayer(
                            studying: _studying,
                            colors: colors,
                            onBack: () => _studying.value = false,
                            onStep: _stepAyah,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (effectiveMode == MushafReadingMode.scroll)
                  ValueListenableBuilder<bool>(
                    valueListenable: _studying,
                    builder: (context, studying, _) => studying
                        ? const SizedBox.shrink()
                        : _NoticeSlot(
                            colors: colors,
                            onReturn: _jumpInPlace,
                            onDownload: _downloadPlaying,
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
        child: ValueListenableBuilder(
          valueListenable: _overlayHeight,
          builder: (context, overlay, _) => ListView.builder(
            controller: _scrollController,
            padding: EdgeInsets.only(bottom: overlay),
            itemCount: 604,
            itemExtent: _scrollPageHeight + _scrollPageGap,
            itemBuilder: (_, i) => Padding(
              padding: const EdgeInsets.only(bottom: _scrollPageGap),
              child: MushafPageView(
                pageNumber: i + 1,
                onOpenFawasil: _openFawasil,
              ),
            ),
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
      chipHeight: _chipHeight,
      child: Directionality(
        textDirection: TextDirection.rtl,
        child: PageView.builder(
          controller: _pageController,
          itemCount: 604,
          onPageChanged: (i) => _setPageFromView(i + 1),
          itemBuilder: (_, i) => Center(
            child: MushafPageView(
              pageNumber: i + 1,
              onOpenFawasil: _openFawasil,
            ),
          ),
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
    required this.chipHeight,
    required this.child,
  });

  final Size area;
  final ValueNotifier<double> overlayHeight;
  final ValueNotifier<double> chipHeight;
  final Widget child;

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: Listenable.merge([overlayHeight, chipHeight]),
    child: child,
    builder: (context, child) =>
        BlocSelector<MushafCubit, MushafState, (double?, double?)>(
          selector: (s) => (
            lineBottomOf(s.pageAyahs, s.selectedAyah ?? s.playingAyah),
            pageBottomOf(s.pageAyahs),
          ),
          builder: (context, bottoms) {
            final (ayahBottom, pageBottom) = bottoms;
            final end = ayahBottom != null
                ? leafSlide(
                    area: area,
                    lineBottom: ayahBottom,
                    overlay: overlayHeight.value,
                  )
                : pageBottom != null
                ? leafSlide(
                    area: area,
                    lineBottom: pageBottom,
                    overlay: chipHeight.value,
                  )
                : 0.0;
            return TweenAnimationBuilder<double>(
              tween: Tween(end: end),
              duration: const Duration(milliseconds: 200),
              child: child,
              builder: (context, slide, child) => Transform.translate(
                key: const ValueKey('page-slide'),
                offset: Offset(0, -slide),
                child: child,
              ),
            );
          },
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
    final chip = switch (notice) {
      null => null,
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
    };
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 200),
      child: chip == null
          ? const SizedBox.shrink(key: ValueKey('no-notice'))
          : Padding(
              key: ValueKey(notice),
              padding: const EdgeInsets.only(bottom: 8),
              child: Center(child: chip),
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
    required this.onNewPlay,
    required this.onFasil,
    required this.studying,
    required this.onExpand,
  });

  final MushafPaperColors colors;
  final ValueListenable<bool> studying;
  final VoidCallback onExpand;
  final VoidCallback onListenFromHere;
  final void Function(AyahIdentifier ayah) onListenFromSurahStart;
  final VoidCallback onListenPage;
  final VoidCallback onNewPlay;
  final VoidCallback onFasil;

  @override
  Widget build(BuildContext context) {
    final mushaf = context.read<MushafCubit>();
    final lead =
        context.select((SettingsCubit c) => c.state.settingsModel.tapAction) ==
        LeafTapAction.meaning;
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
                    ? ValueListenableBuilder<bool>(
                        key: ValueKey(selected),
                        valueListenable: studying,
                        builder: (context, studying, _) => ExcludeSemantics(
                          excluding: studying,
                          child: AyahLeaf(
                            ayah: selected,
                            colors: colors,
                            onClose: mushaf.clearSelection,
                            onListenFromHere: onListenFromHere,
                            onListenFromSurahStart: () =>
                                onListenFromSurahStart(selected),
                            onListenPage: onListenPage,
                            onFasil: onFasil,
                            onExpand: onExpand,
                            tafsirLead: lead,
                          ),
                        ),
                      )
                    : active
                    ? _PlayerSlot(
                        key: const ValueKey('player'),
                        colors: colors,
                        onNewPlay: onNewPlay,
                      )
                    : const SizedBox.shrink(),
              ),
            ),
      ),
    );
  }
}

class _StudyLayer extends StatefulWidget {
  const _StudyLayer({
    required this.studying,
    required this.colors,
    required this.onBack,
    required this.onStep,
  });

  final ValueListenable<bool> studying;
  final MushafPaperColors colors;
  final VoidCallback onBack;
  final void Function(int delta) onStep;

  @override
  State<_StudyLayer> createState() => _StudyLayerState();
}

class _StudyLayerState extends State<_StudyLayer> {
  int? _boundsPage;
  Future<List<AyahBoundEntity>>? _bounds;

  Widget _leaf(BuildContext context, MushafState state, AyahIdentifier ayah) {
    final page = sl<QuranPageService>().getPageForAyah(ayah.surah, ayah.ayah);
    if (page != _boundsPage) {
      _boundsPage = page;
      _bounds = context.read<MushafCubit>().boundsFor(page);
    }
    final previous = adjacentAyah(ayah, -1);
    final next = adjacentAyah(ayah, 1);
    return FutureBuilder(
      key: ValueKey(page),
      future: _bounds,
      initialData: page == state.currentPage && state.pageAyahs.isNotEmpty
          ? state.pageAyahs
          : null,
      builder: (context, snapshot) => AyahStudyLeaf(
        key: const ValueKey('study-leaf'),
        ayah: ayah,
        page: page,
        lines:
            snapshot.data?.where((b) => b.ayah == ayah).firstOrNull?.lines ??
            const [],
        colors: widget.colors,
        onBack: widget.onBack,
        onPrevious: previous == null ? null : () => widget.onStep(-1),
        onNext: next == null ? null : () => widget.onStep(1),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder<bool>(
    valueListenable: widget.studying,
    builder: (context, studying, _) => BlocBuilder<MushafCubit, MushafState>(
      buildWhen: (a, b) =>
          a.selectedAyah != b.selectedAyah ||
          a.currentPage != b.currentPage ||
          a.pageAyahs != b.pageAyahs,
      builder: (context, state) {
        final ayah = state.selectedAyah;
        return AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: studying && ayah != null && ayah.ayah != 0
              ? GestureDetector(
                  key: const ValueKey('study'),
                  behavior: HitTestBehavior.opaque,
                  child: _leaf(context, state, ayah),
                )
              : const SizedBox.shrink(key: ValueKey('no-study')),
        );
      },
    ),
  );
}

class _PlayerSlot extends StatelessWidget {
  const _PlayerSlot({super.key, required this.colors, required this.onNewPlay});

  final MushafPaperColors colors;
  final VoidCallback onNewPlay;

  @override
  Widget build(BuildContext context) {
    final mushaf = context.read<MushafCubit>();
    return BlocBuilder<MushafCubit, MushafState>(
      buildWhen: (a, b) =>
          a.followPlayback != b.followPlayback ||
          a.playingAyah != b.playingAyah,
      builder: (context, state) {
        final playing = mushaf.playingTarget;
        final page = mushaf.playingPage;
        return PlayerLeaf(
          colors: colors,
          away: !state.followPlayback && playing != null && page != null
              ? (ayah: playing, page: page)
              : null,
          onReturnToPlaying: mushaf.resumeFollow,
          onNewPlay: onNewPlay,
        );
      },
    );
  }
}
