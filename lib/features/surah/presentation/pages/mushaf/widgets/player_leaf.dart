import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/quran_playback/presentation/widgets/playback_options_sheet.dart';
import 'package:quran_app/features/quran_playback/presentation/widgets/surah_download_button.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/surah/presentation/utils/reader_rules.dart';
import 'package:quran_app/generated/l10n.dart';

const _tapSize = ButtonStyle(minimumSize: WidgetStatePropertyAll(Size(0, 48)));

class PlayerLeaf extends StatelessWidget {
  const PlayerLeaf({
    super.key,
    required this.colors,
    required this.onReturnToPlaying,
    required this.onNewPlay,
    this.away,
  });

  final MushafPaperColors colors;
  final VoidCallback onReturnToPlaying;
  final VoidCallback onNewPlay;
  final ({AyahIdentifier ayah, int page})? away;

  @override
  Widget build(BuildContext context) {
    final pending = PendingS.of(context);
    final away = this.away;
    return Material(
      color: colors.leaf,
      shape: Border(top: BorderSide(color: colors.accent)),
      child: OutlinedButtonTheme(
        data: OutlinedButtonThemeData(
          style: colors.paperButton(outlined: true),
        ),
        child: TextButtonTheme(
          data: TextButtonThemeData(style: colors.paperButton()),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              BlocSelector<PlaybackCubit, PlaybackState, bool>(
                selector: (state) => state.isLoading,
                builder: (context, loading) => loading
                    ? LinearProgressIndicator(
                        key: const ValueKey('player-loading'),
                        minHeight: 2,
                        color: colors.accent,
                      )
                    : const SizedBox.shrink(),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 12,
                  children: [
                    if (away != null)
                      Wrap(
                        spacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            pending.mushaf_nowReciting(
                              surahDisplayName(context, away.ayah.surah),
                              away.ayah.realAyah.toLocalized(context),
                              away.page.toLocalized(context),
                            ),
                            style: TS.medium14.copyWith(color: colors.ink),
                          ),
                          FilledButton(
                            key: const ValueKey('player-return'),
                            style: _tapSize,
                            onPressed: onReturnToPlaying,
                            child: Text(pending.mushaf_returnToReciting),
                          ),
                        ],
                      ),
                    _Title(colors: colors),
                    _Controls(colors: colors, onNewPlay: onNewPlay),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Title extends StatelessWidget {
  const _Title({required this.colors});

  final MushafPaperColors colors;

  @override
  Widget build(BuildContext context) {
    final pending = PendingS.of(context);
    return BlocSelector<
      PlaybackCubit,
      PlaybackState,
      (AyahIdentifier?, AyahIdentifier?, AyahIdentifier?, Reciter)
    >(
      selector: (state) =>
          (state.skipOrigin, state.rangeStart, state.rangeEnd, state.reciter),
      builder: (context, title) {
        final (origin, start, end, reciter) = title;
        final subtitle = switch (playbackScope(start, end)) {
          PlaybackScope.surahEnd => pending.player_untilSurahEnd(
            reciter.arabicName,
          ),
          PlaybackScope.pageEnd => pending.player_untilPageEnd(
            reciter.arabicName,
          ),
          PlaybackScope.none => reciter.arabicName,
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              origin == null
                  ? ''
                  : pending.playback_mediaTitle(
                      surahDisplayName(context, origin.surah),
                      origin.realAyah.toLocalized(context),
                    ),
              style: TS.bold16.copyWith(color: colors.ink),
            ),
            Text(subtitle, style: TS.medium14.copyWith(color: colors.ink2)),
          ],
        );
      },
    );
  }
}

class _Controls extends StatelessWidget {
  const _Controls({required this.colors, required this.onNewPlay});

  final MushafPaperColors colors;
  final VoidCallback onNewPlay;

  @override
  Widget build(BuildContext context) =>
      BlocSelector<PlaybackCubit, PlaybackState, AyahIdentifier?>(
        selector: (state) => state.error != null ? state.skipOrigin : null,
        builder: (context, failed) => failed != null
            ? _Error(colors: colors, origin: failed)
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: 12,
                children: [
                  _Transport(colors: colors, onNewPlay: onNewPlay),
                  _Actions(colors: colors, onNewPlay: onNewPlay),
                ],
              ),
      );
}

class _Error extends StatelessWidget {
  const _Error({required this.colors, required this.origin});

  final MushafPaperColors colors;
  final AyahIdentifier origin;

  @override
  Widget build(BuildContext context) {
    final pending = PendingS.of(context);
    final cubit = context.read<PlaybackCubit>();
    return Semantics(
      liveRegion: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 4,
        children: [
          Text(
            pending.mushaf_audioError(
              surahDisplayName(context, origin.surah),
              origin.realAyah.toLocalized(context),
            ),
            style: TS.semi14.copyWith(color: colors.ink),
          ),
          Text(
            pending.mushaf_audioErrorHint,
            style: TS.regular14.copyWith(color: colors.ink2),
          ),
          Wrap(
            spacing: 8,
            children: [
              FilledButton(
                key: const ValueKey('player-retry'),
                style: _tapSize,
                onPressed: cubit.retry,
                child: Text(pending.mushaf_retry),
              ),
              TextButton(
                key: const ValueKey('player-end'),
                style: _tapSize,
                onPressed: cubit.stop,
                child: Text(pending.mushaf_endRecitation),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Transport extends StatelessWidget {
  const _Transport({required this.colors, required this.onNewPlay});

  final MushafPaperColors colors;
  final VoidCallback onNewPlay;

  Widget _label(String text) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, style: TS.semi14, maxLines: 1),
  );

  @override
  Widget build(BuildContext context) {
    final pending = PendingS.of(context);
    final cubit = context.read<PlaybackCubit>();
    return BlocSelector<PlaybackCubit, PlaybackState, (bool, bool, bool, bool)>(
      selector: (state) => (
        state.isPlaying,
        state.isLoading,
        state.canSkipPrevious,
        state.canSkipNext,
      ),
      builder: (context, flags) {
        final (isPlaying, isLoading, canPrevious, canNext) = flags;
        return Row(
          spacing: 8,
          children: [
            Expanded(
              child: TextButton.icon(
                key: const ValueKey('player-previous'),
                style: _tapSize,
                icon: Icon(skipBackIcon(context)),
                label: _label(pending.player_previous),
                onPressed: canPrevious
                    ? () {
                        cubit.skipPrevious();
                        onNewPlay();
                      }
                    : null,
              ),
            ),
            Expanded(
              flex: 2,
              child: FilledButton.icon(
                key: const ValueKey('player-toggle'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size(0, 56),
                  disabledBackgroundColor: colors.ink.withValues(alpha: 0.12),
                  disabledForegroundColor: colors.ink.withValues(alpha: 0.38),
                ),
                icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
                label: _label(
                  isPlaying
                      ? S.of(context).playback_pause
                      : pending.player_resume,
                ),
                onPressed: isLoading
                    ? null
                    : isPlaying
                    ? cubit.pause
                    : cubit.resume,
              ),
            ),
            Expanded(
              child: TextButton.icon(
                key: const ValueKey('player-next'),
                style: _tapSize,
                icon: Icon(skipForwardIcon(context)),
                label: _label(pending.player_next),
                onPressed: canNext
                    ? () {
                        cubit.skipNext();
                        onNewPlay();
                      }
                    : null,
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Actions extends StatelessWidget {
  const _Actions({required this.colors, required this.onNewPlay});

  final MushafPaperColors colors;
  final VoidCallback onNewPlay;

  @override
  Widget build(BuildContext context) {
    final pending = PendingS.of(context);
    final cubit = context.read<PlaybackCubit>();
    return BlocSelector<PlaybackCubit, PlaybackState, (bool, int, int, int?)>(
      selector: (state) => (
        state.infiniteRepeat,
        state.eachAyahRepeat,
        state.rangeRepeat,
        state.skipOrigin?.surah,
      ),
      builder: (context, actions) {
        final (infinite, each, range, surah) = actions;
        final repeat = infinite
            ? pending.player_repeatForever
            : each > 1 || range > 1
            ? pending.player_repeatCounts(
                each.toLocalized(context),
                range.toLocalized(context),
              )
            : pending.player_repeatOnce;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('player-repeat'),
              style: _tapSize,
              icon: const Icon(Icons.repeat),
              label: Text(pending.player_repeat(repeat), style: TS.medium14),
              onPressed: () =>
                  PlaybackOptionsSheet.show(context, onNewPlay: onNewPlay),
            ),
            if (surah != null)
              SurahDownloadButton(
                surah: surah,
                labelled: true,
                foreground: colors.ink,
              ),
            TextButton.icon(
              key: const ValueKey('player-end'),
              style: _tapSize,
              icon: const Icon(Icons.stop),
              label: Text(pending.mushaf_endRecitation, style: TS.medium14),
              onPressed: cubit.stop,
            ),
          ],
        );
      },
    );
  }
}
