import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_page_cache.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_spans_cache.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/surah_header.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../../core/di/dependency_injection.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';

class MushafPage extends StatefulWidget {
  const MushafPage({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> with WidgetsBindingObserver {
  late final PageController _pageController;
  bool _precachedHeader = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _pageController = PageController(initialPage: widget.pageNumber - 1);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_precachedHeader) {
      precacheImage(kSurahHeaderImage, context);
      _precachedHeader = true;
    }
  }

  @override
  void didHaveMemoryPressure() {
    sl<MushafSpansCache>().clear();
    final current =
        (_pageController.page ?? _pageController.initialPage).round() + 1;
    sl<MushafPageCache>().trimAround(pivot: current, keep: 5);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mediaSize = MediaQuery.sizeOf(context);
    final pageWidth = mediaSize.width;
    final fontSize = pageWidth / 15 * 0.9;
    final lineHeight = pageWidth / 15 * 1.8;
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      body: BlocListener<PlaybackCubit, PlaybackState>(
        listenWhen: (p, c) => p.currentAyah != c.currentAyah,
        listener: (context, state) {
          final cubit = context.read<PlaybackCubit>();
          final targetPage = cubit.getPageForCurrentAyah();
          if (targetPage == null) return;
          if (!_pageController.hasClients) return;
          final currentIndex =
              (_pageController.page ?? _pageController.initialPage).round();
          final targetIndex = targetPage - 1;
          if (currentIndex != targetIndex) {
            _pageController.animateToPage(
              targetIndex,
              duration: const Duration(milliseconds: 350),
              curve: Curves.easeInOut,
            );
          }
        },
        child: PageView.builder(
          controller: _pageController,
          reverse: context.isArabic ? false : true,
          itemCount: 604,
          allowImplicitScrolling: false,
          itemBuilder: (context, index) {
            final pageNumber = index + 1;
            return BlocProvider<MushafCubit>(
              create: (_) {
                final cubit = sl<MushafCubit>();
                final hit = cubit.loadPageSync(
                  pageNumber: pageNumber,
                  colorScheme: colorScheme,
                  fontSize: fontSize,
                  lineHeight: lineHeight,
                  pageWidth: pageWidth,
                  builderContext: context,
                );
                if (!hit) {
                  cubit.loadPage(
                    pageNumber: pageNumber,
                    colorScheme: colorScheme,
                    fontSize: fontSize,
                    lineHeight: lineHeight,
                    pageWidth: pageWidth,
                    builderContext: context,
                  );
                }
                return cubit;
              },
              child: MushafPageContent(pageNumber: pageNumber),
            );
          },
        ),
      ),
      floatingActionButton: _FabColumn(controller: _pageController),
    );
  }
}

class _FabColumn extends StatelessWidget {
  const _FabColumn({required this.controller});

  final PageController controller;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        FloatingActionButton(
          heroTag: 'autoplay_page',
          tooltip: 'Autoplay this page',
          onPressed: () {
            final currentIndex =
                (controller.page ?? controller.initialPage).round();
            context.read<PlaybackCubit>().autoPlayPage(currentIndex + 1);
          },
          child: const Icon(Icons.play_arrow),
        ),
        const SizedBox(height: 8),
        BlocBuilder<PlaybackCubit, PlaybackState>(
          buildWhen: (p, c) => p.isPlaying != c.isPlaying,
          builder: (context, state) {
            return FloatingActionButton(
              heroTag: 'pause_playback',
              tooltip: state.isPlaying ? 'Pause playback' : 'Resume playback',
              onPressed: () {
                final cubit = context.read<PlaybackCubit>();
                if (state.isPlaying) {
                  cubit.pause();
                } else {
                  cubit.resume();
                }
              },
              child: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
            );
          },
        ),
        const SizedBox(height: 8),
        FloatingActionButton(
          heroTag: 'stop_playback',
          tooltip: 'Stop playback',
          onPressed: () => context.read<PlaybackCubit>().stop(),
          child: const Icon(Icons.stop),
        ),
      ],
    );
  }
}
