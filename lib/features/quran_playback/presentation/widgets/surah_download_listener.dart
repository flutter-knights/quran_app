import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_state.dart';

class SurahDownloadListener extends StatelessWidget {
  const SurahDownloadListener({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<PlaybackCubit, PlaybackState>(
        listenWhen: (a, b) => a.reciter != b.reciter,
        listener: (context, state) =>
            context.read<SurahDownloadCubit>().refresh(state.reciter),
      ),
      BlocListener<SurahDownloadCubit, SurahDownloadState>(
        listenWhen: (a, b) => b.statuses.entries.any(
          (e) =>
              e.value is SurahDownloadFailed &&
              a.statuses[e.key] is! SurahDownloadFailed,
        ),
        listener: (context, _) => ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              PendingS.current.surahDownload_failed,
              style: TS.regular14,
            ),
          ),
        ),
      ),
    ],
    child: child,
  );
}
