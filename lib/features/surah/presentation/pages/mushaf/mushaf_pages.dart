import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/features/quran_playback/data/repositories/helper/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_content.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

import '../../../../../core/di/dependency_injection.dart';
import '../../cubit/mushaf/mushaf_cubit.dart';

class MushafPage extends StatefulWidget {
  final int pageNumber;
  const MushafPage({super.key, required this.pageNumber});

  @override
  State<MushafPage> createState() => _MushafPageState();
}

class _MushafPageState extends State<MushafPage> {
  late PageController _pageController;
  @override
  void initState() {
    super.initState();
    SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    WakelockPlus.enable();
    _pageController = PageController(initialPage: widget.pageNumber - 1);
  }

  @override
  void dispose() {
    _pageController.dispose();

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    WakelockPlus.disable();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: BlocListener<PlaybackCubit, PlaybackState>(
        listenWhen: (previous, current) =>
            previous.currentAyah != current.currentAyah,
        listener: (context, state) {
          final ayah = state.currentAyah;
          if (ayah == null) return;
          try {
            final targetPage = quran.getPageNumber(ayah.surah, ayah.ayah);
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
          } catch (e) {
            // ignore mapping errors
          }
        },
        child: PageView.builder(
          controller: _pageController,
          reverse: context.isArabic ? false : true,
          itemCount: 604,
          itemBuilder: (context, index) {
            int pageNumber = index + 1;
            return BlocProvider(
              create: (_) => sl<MushafCubit>()..loadPage(pageNumber),
              child: MushafPageContent(pageNumber: pageNumber),
            );
          },
        ),
      ),
      // floatingActionButton: Column(
      //   mainAxisSize: MainAxisSize.min,
      //   children: [
      //     FloatingActionButton(
      //       heroTag: 'autoplay_page',
      //       tooltip: 'Autoplay this page',
      //       child: const Icon(Icons.play_arrow),
      //       onPressed: () {
      //         final currentIndex =
      //             (_pageController.page ?? _pageController.initialPage).round();
      //         final pageNumber = currentIndex + 1;

      //         try {
      //           final pageData = quran.getPageData(pageNumber);
      //           if (pageData.isEmpty) return;
      //           final first = pageData.first as Map;
      //           final startSurah = first['surah'] as int;
      //           final startAyah = first['start'] as int;

      //           final cubit = context.read<PlaybackCubit>();
      //           cubit.startAutoPlay(
      //             startSurah: startSurah,
      //             startAyah: startAyah,
      //             reciter: Reciter.alafasy,
      //           );
      //         } catch (e) {
      //           // ignore
      //         }
      //       },
      //     ),
      //     const SizedBox(height: 8),
      //     BlocBuilder<PlaybackCubit, PlaybackState>(
      //       buildWhen: (p, c) => p.isPlaying != c.isPlaying,
      //       builder: (context, state) {
      //         return FloatingActionButton(
      //           heroTag: 'pause_playback',
      //           tooltip: state.isPlaying ? 'Pause playback' : 'Resume playback',
      //           child: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
      //           onPressed: () {
      //             try {
      //               final cubit = context.read<PlaybackCubit>();
      //               if (state.isPlaying) {
      //                 cubit.pause();
      //               } else {
      //                 cubit.resume();
      //               }
      //             } catch (e) {
      //               // ignore
      //             }
      //           },
      //         );
      //       },
      //     ),
      //     const SizedBox(height: 8),
      //     FloatingActionButton(
      //       heroTag: 'stop_playback',
      //       tooltip: 'Stop playback',
      //       child: const Icon(Icons.stop),
      //       onPressed: () {
      //         try {
      //           final cubit = context.read<PlaybackCubit>();
      //           cubit.stop();
      //         } catch (e) {
      //           // ignore
      //         }
      //       },
      //     ),
      //   ],
      // ),
    );
  }
}
