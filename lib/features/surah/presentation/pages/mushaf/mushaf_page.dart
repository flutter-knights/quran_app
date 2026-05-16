import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../../core/di/dependency_injection.dart';
import '../../../../quran_playback/domain/services/quran_page_service.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';
import '../../cubit/mushaf/mushaf_state.dart';
import 'auto_swap_helper.dart';
import 'widgets/ayah_action_bar.dart';
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

  @override
  void initState() {
    super.initState();
    _controller = PageController(initialPage: widget.initialPage - 1);
    _controller.addListener(_precacheNeighbours);
  }

  @override
  void dispose() {
    _controller.removeListener(_precacheNeighbours);
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
                child: Directionality(
                  textDirection: TextDirection.rtl,
                  child: PageView.builder(
                    controller: _controller,
                    itemCount: 604,
                    onPageChanged: (i) =>
                        context.read<MushafCubit>().setPage(_pageNumberFor(i)),
                    itemBuilder: (_, i) =>
                        MushafPageView(pageNumber: _pageNumberFor(i)),
                  ),
                ),
              ),
              const AyahActionBar(),
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
