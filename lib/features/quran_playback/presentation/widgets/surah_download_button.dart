import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/surah_download/surah_download_state.dart';

class SurahDownloadButton extends StatelessWidget {
  const SurahDownloadButton({super.key, required this.surah});

  final int surah;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<PlaybackCubit, PlaybackState, Reciter>(
        selector: (state) => state.reciter,
        builder: (context, reciter) {
          final key = reciter.downloadKey(surah);
          return BlocListener<SurahDownloadCubit, SurahDownloadState>(
            listenWhen: (a, b) =>
                a.statuses[key] != b.statuses[key] &&
                b.statuses[key] is SurahDownloadFailed,
            listener: (context, _) =>
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      PendingS.of(context).surahDownload_failed,
                      style: TS.regular14,
                    ),
                  ),
                ),
            child: BlocBuilder<SurahDownloadCubit, SurahDownloadState>(
              buildWhen: (a, b) => a.statuses[key] != b.statuses[key],
              builder: (context, _) {
                final cubit = context.read<SurahDownloadCubit>();
                return _button(
                  context,
                  cubit,
                  reciter,
                  cubit.statusOf(reciter, surah),
                );
              },
            ),
          );
        },
      );

  Widget _button(
    BuildContext context,
    SurahDownloadCubit cubit,
    Reciter reciter,
    SurahDownloadStatus status,
  ) {
    final scheme = context.colorScheme;
    final pending = PendingS.of(context);
    final (child, tooltip, onTap) = switch (status) {
      SurahNotDownloaded() => (
        Icon(Icons.download_for_offline_outlined, color: scheme.secondary),
        pending.surahDownload_download,
        () => cubit.download(reciter, surah),
      ),
      SurahDownloading(:final progress) => (
        Semantics(
          label: pending.surahDownload_progress(
            (progress * 100).round().toLocalized(context),
          ),
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(value: progress, strokeWidth: 2.5),
          ),
        ),
        pending.surahDownload_cancel,
        () => cubit.cancel(reciter, surah),
      ),
      SurahDownloaded() => (
        Icon(Icons.offline_pin, color: scheme.primary),
        pending.surahDownload_saved,
        () => _confirmDelete(context, cubit, reciter),
      ),
      SurahDownloadFailed() => (
        Icon(Icons.error_outline, color: scheme.error),
        pending.surahDownload_failed,
        () => cubit.download(reciter, surah),
      ),
    };
    return IconButton(
      constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
      tooltip: tooltip,
      icon: child,
      onPressed: onTap,
    );
  }

  Future<void> _confirmDelete(
    BuildContext context,
    SurahDownloadCubit cubit,
    Reciter reciter,
  ) {
    final pending = PendingS.of(context);
    return showDialog<void>(
      context: context,
      builder: (dialog) => AlertDialog(
        content: Text(pending.surahDownload_saved, style: TS.regular14),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialog).pop(),
            child: Text(MaterialLocalizations.of(dialog).cancelButtonLabel),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(dialog).pop();
              cubit.delete(reciter, surah);
            },
            child: Text(pending.surahDownload_delete),
          ),
        ],
      ),
    );
  }
}
