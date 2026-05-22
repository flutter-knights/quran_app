import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/dependency_injection.dart';
import '../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../quran_playback/domain/services/quran_page_service.dart';
import '../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../domain/entities/last_read.dart';
import '../../cubit/last_read/last_read_cubit.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';
import '../../cubit/mushaf/mushaf_state.dart';
import 'auto_swap_helper.dart';
import 'widgets/ayah_playback_overlay.dart';
import 'widgets/mushaf_page_number_text.dart';
import 'widgets/mushaf_page_view.dart';

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
          child: Column(
            children: [
              Expanded(
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
                    const AyahPlaybackOverlay(),
                    BlocBuilder<MushafCubit, MushafState>(
                      buildWhen: (a, b) =>
                          a.highlightedAyah != b.highlightedAyah ||
                          a.isOverlayPinned != b.isOverlayPinned,
                      builder: (context, state) {
                        final fabVisible =
                            state.highlightedAyah == null &&
                                !state.isOverlayPinned;
                        return PositionedDirectional(
                          bottom: 16,
                          end: 16,
                          child: IgnorePointer(
                            ignoring: !fabVisible,
                            child: AnimatedScale(
                              scale: fabVisible ? 1.0 : 0.0,
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              child: AnimatedOpacity(
                                opacity: fabVisible ? 1.0 : 0.0,
                                duration: const Duration(milliseconds: 180),
                                child: FloatingActionButton(
                                  onPressed: () {
                                    final mushafCubit =
                                        context.read<MushafCubit>();
                                    var firstAyah =
                                        sl<QuranPageService>()
                                            .getFirstAyahOfPage(
                                                mushafCubit.state.currentPage);
                                    if (firstAyah != null) {
                                      if (firstAyah.ayah == 1 &&
                                          firstAyah.surah != 1 &&
                                          firstAyah.surah != 9) {
                                        firstAyah = AyahIdentifier(
                                            surah: firstAyah.surah, ayah: 0);
                                      }
                                      mushafCubit.toggleHighlight(firstAyah);
                                    } else {
                                      mushafCubit.pinOverlay();
                                    }
                                  },
                                  child: const Icon(Icons.headphones),
                                ),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ),
              BlocBuilder<MushafCubit, MushafState>(
                buildWhen: (a, b) => a.currentPage != b.currentPage,
                builder: (context, state) =>
                    MushafPageNumberText(pageNumber: state.currentPage),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
