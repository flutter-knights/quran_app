import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/dependency_injection.dart';
import '../../../../quran_playback/domain/services/quran_page_service.dart';
import '../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../domain/entities/last_read.dart';
import '../../cubit/last_read/last_read_cubit.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';
import '../../cubit/mushaf/mushaf_state.dart';
import 'auto_swap_helper.dart';
import 'widgets/ayah_playback_overlay.dart';
import 'widgets/mushaf_bottom_bar.dart';
import 'widgets/mushaf_page_view.dart';
import 'widgets/mushaf_top_bar.dart';

class MushafPage extends StatefulWidget {
  const MushafPage({super.key, required this.initialPage});
  final int initialPage;

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  late final PageController _controller;
  late final MushafCubit _mushafCubit;
  late final PlaybackCubit _playbackCubit;
  late final LastReadCubit _lastReadCubit;

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialPage - 1);
    _controller.addListener(_precacheNeighbours);

    _mushafCubit = context.read<MushafCubit>();
    _playbackCubit = context.read<PlaybackCubit>();
    _lastReadCubit = context.read<LastReadCubit>();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_mushafCubit.state.highlightedAyah != null) return; // focus ayah already set
      final last = _lastReadCubit.state;
      if (last?.ayah == null) return;
      if (last!.page != widget.initialPage) return;
      _mushafCubit.toggleHighlight(last.ayah!);
    });
  }

  @override
  void dispose() {
    _controller.removeListener(_precacheNeighbours);

    final mushafState = _mushafCubit.state;
    final ayah = mushafState.highlightedAyah ?? _playbackCubit.state.currentAyah;
    _lastReadCubit
        .save(LastRead(page: mushafState.currentPage, ayah: ayah))
        .catchError((_) {});
    _playbackCubit.stop();

    _controller.dispose();
    super.dispose();
  }

  int _pageNumberFor(int index) => index + 1;

  void _precacheNeighbours() {
    final idx = _controller.page?.round();
    if (idx == null) return;
    for (final neighbour in [idx - 1, idx + 1]) {
      if (neighbour < 0 || neighbour > 603) continue;
      final page = _pageNumberFor(neighbour);
      precacheImage(
        AssetImage(
            'assets/mushaf/pages/page_${page.toString().padLeft(3, '0')}.png'),
        context,
      );
    }
  }

  void _onPlayingAyahChanged(MushafState state) {
    if (!_controller.hasClients) return;
    final targetIdx = computeAutoSwapTargetIndex(
      playingAyah: state.playingAyah,
      currentPageIndex: _controller.page?.round(),
      pageService: sl<QuranPageService>(),
    );
    if (targetIdx == null) return;
    _controller.animateToPage(
      targetIdx,
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocListener<MushafCubit, MushafState>(
      listenWhen: (a, b) => a.playingAyah != b.playingAyah,
      listener: (_, state) => _onPlayingAyahChanged(state),
      child: Scaffold(
        body: SafeArea(
          child: Stack(
            children: [
              Positioned.fill(
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: 604,
                    onPageChanged: (i) =>
                        _mushafCubit.setPage(_pageNumberFor(i)),
                    itemBuilder: (_, i) =>
                        MushafPageView(pageNumber: _pageNumberFor(i)),
                  ),
                ),
              ),
              // TOP chrome
              BlocBuilder<MushafCubit, MushafState>(
                buildWhen: (a, b) =>
                    a.chromeVisible != b.chromeVisible ||
                    a.currentPage != b.currentPage,
                builder: (context, state) => Align(
                  alignment: Alignment.topCenter,
                  child: AnimatedSlide(
                    offset: state.chromeVisible
                        ? Offset.zero
                        : const Offset(0, -1),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: state.chromeVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: IgnorePointer(
                        ignoring: !state.chromeVisible,
                        child: MushafTopBar(pageNumber: state.currentPage),
                      ),
                    ),
                  ),
                ),
              ),
              // BOTTOM chrome
              BlocBuilder<MushafCubit, MushafState>(
                buildWhen: (a, b) => a.chromeVisible != b.chromeVisible,
                builder: (context, state) => Align(
                  alignment: Alignment.bottomCenter,
                  child: AnimatedSlide(
                    offset: state.chromeVisible
                        ? Offset.zero
                        : const Offset(0, 1),
                    duration: const Duration(milliseconds: 220),
                    curve: Curves.easeOutCubic,
                    child: AnimatedOpacity(
                      opacity: state.chromeVisible ? 1 : 0,
                      duration: const Duration(milliseconds: 180),
                      child: IgnorePointer(
                        ignoring: !state.chromeVisible,
                        child: const MushafBottomBar(),
                      ),
                    ),
                  ),
                ),
              ),
              const AyahPlaybackOverlay(),
            ],
          ),
        ),
      ),
    );
  }
}
