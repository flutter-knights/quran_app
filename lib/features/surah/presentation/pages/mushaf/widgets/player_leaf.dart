import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
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
      child: BlocBuilder<PlaybackCubit, PlaybackState>(
        buildWhen: (a, b) =>
            a.isPlaying != b.isPlaying ||
            a.isLoading != b.isLoading ||
            a.currentAyah != b.currentAyah ||
            a.requestedAyah != b.requestedAyah ||
            a.error != b.error ||
            a.rangeStart != b.rangeStart ||
            a.rangeEnd != b.rangeEnd ||
            a.reciter != b.reciter ||
            a.eachAyahRepeat != b.eachAyahRepeat ||
            a.rangeRepeat != b.rangeRepeat ||
            a.infiniteRepeat != b.infiniteRepeat,
        builder: (context, state) {
          final cubit = context.read<PlaybackCubit>();
          final origin = state.skipOrigin;
          final name = origin == null
              ? ''
              : surahDisplayName(context, origin.surah);
          final reciter = state.reciter.arabicName;
          final subtitle = switch (playbackScope(
            state.rangeStart,
            state.rangeEnd,
          )) {
            PlaybackScope.surahEnd => pending.player_untilSurahEnd(reciter),
            PlaybackScope.pageEnd => pending.player_untilPageEnd(reciter),
            PlaybackScope.none => reciter,
          };
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.isLoading)
                const LinearProgressIndicator(
                  key: ValueKey('player-loading'),
                  minHeight: 2,
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
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          origin == null
                              ? ''
                              : pending.playback_mediaTitle(
                                  name,
                                  origin.realAyah.toLocalized(context),
                                ),
                          style: TS.bold16.copyWith(color: colors.ink),
                        ),
                        Text(
                          subtitle,
                          style: TS.medium14.copyWith(color: colors.ink2),
                        ),
                      ],
                    ),
                    if (state.error != null && origin != null)
                      _error(context, pending, cubit, origin)
                    else ...[
                      _transport(context, pending, cubit, state),
                      _actions(context, pending, cubit, state),
                    ],
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _error(
    BuildContext context,
    PendingS pending,
    PlaybackCubit cubit,
    AyahIdentifier origin,
  ) => Semantics(
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

  Widget _label(String text) => FittedBox(
    fit: BoxFit.scaleDown,
    child: Text(text, style: TS.semi14, maxLines: 1),
  );

  Widget _transport(
    BuildContext context,
    PendingS pending,
    PlaybackCubit cubit,
    PlaybackState state,
  ) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Row(
      spacing: 8,
      children: [
        Expanded(
          child: TextButton.icon(
            key: const ValueKey('player-previous'),
            style: _tapSize,
            icon: Icon(rtl ? Icons.skip_next : Icons.skip_previous),
            label: _label(pending.player_previous),
            onPressed: state.canSkipPrevious
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
            style: FilledButton.styleFrom(minimumSize: const Size(0, 56)),
            icon: Icon(state.isPlaying ? Icons.pause : Icons.play_arrow),
            label: _label(
              state.isPlaying
                  ? S.of(context).playback_pause
                  : pending.player_resume,
            ),
            onPressed: state.isLoading
                ? null
                : state.isPlaying
                ? cubit.pause
                : cubit.resume,
          ),
        ),
        Expanded(
          child: TextButton.icon(
            key: const ValueKey('player-next'),
            style: _tapSize,
            icon: Icon(rtl ? Icons.skip_previous : Icons.skip_next),
            label: _label(pending.strip_next),
            onPressed: state.canSkipNext
                ? () {
                    cubit.skipNext();
                    onNewPlay();
                  }
                : null,
          ),
        ),
      ],
    );
  }

  Widget _actions(
    BuildContext context,
    PendingS pending,
    PlaybackCubit cubit,
    PlaybackState state,
  ) {
    final origin = state.skipOrigin;
    final repeat = state.infiniteRepeat
        ? pending.player_repeatForever
        : state.eachAyahRepeat > 1 || state.rangeRepeat > 1
        ? pending.player_repeatCounts(
            state.eachAyahRepeat.toLocalized(context),
            state.rangeRepeat.toLocalized(context),
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
        if (origin != null)
          SurahDownloadButton(surah: origin.surah, labelled: true),
        TextButton.icon(
          key: const ValueKey('player-end'),
          style: _tapSize,
          icon: const Icon(Icons.stop),
          label: Text(pending.mushaf_endRecitation, style: TS.medium14),
          onPressed: cubit.stop,
        ),
      ],
    );
  }
}
