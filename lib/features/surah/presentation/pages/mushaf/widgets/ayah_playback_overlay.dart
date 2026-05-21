import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as q;

import '../../../../../../generated/l10n.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_state.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';

const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

class AyahPlaybackOverlay extends StatelessWidget {
  const AyahPlaybackOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MushafCubit, MushafState>(
      buildWhen: (a, b) => a.highlightedAyah != b.highlightedAyah,
      builder: (context, mushafState) {
        final target = mushafState.highlightedAyah;
        final visible = target != null;
        return IgnorePointer(
          ignoring: !visible,
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: visible ? _Body(target: target) : const SizedBox.shrink(),
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.target});
  final AyahIdentifier target;

  bool get _isFirst => target.surah == 1 && target.ayah == 1;
  bool get _isLast =>
      target.surah == 114 && target.ayah == q.getVerseCount(114);

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Material(
      elevation: 8,
      color: Theme.of(context).colorScheme.surface,
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsetsDirectional.symmetric(
              horizontal: 8, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    tooltip: s.playback_close,
                    onPressed: () {
                      context.read<PlaybackCubit>().stop();
                      context.read<MushafCubit>().clearHighlight();
                    },
                  ),
                  Expanded(
                    child: Text(
                      s.ayah_label(
                          target.surah.toString(), target.ayah.toString()),
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.titleSmall,
                    ),
                  ),
                  _SpeedChip(),
                ],
              ),
              BlocBuilder<PlaybackCubit, PlaybackState>(
                buildWhen: (a, b) =>
                    a.isPlaying != b.isPlaying ||
                    a.isLoading != b.isLoading ||
                    a.currentAyah != b.currentAyah,
                builder: (context, p) {
                  final isTargetPlaying = p.currentAyah == target && p.isPlaying;
                  return Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      IconButton(
                        icon: const Icon(Icons.skip_previous),
                        tooltip: s.playback_previous,
                        onPressed: _isFirst
                            ? null
                            : () => context.read<PlaybackCubit>().skipPrevious(),
                      ),
                      IconButton(
                        icon: const Icon(Icons.replay),
                        tooltip: s.playback_restart,
                        onPressed: p.currentAyah == null
                            ? null
                            : () => context.read<PlaybackCubit>().restartCurrent(),
                      ),
                      _PlayPauseButton(
                        target: target,
                        isPlaying: isTargetPlaying,
                        isLoading: p.isLoading,
                      ),
                      IconButton(
                        icon: const Icon(Icons.skip_next),
                        tooltip: s.playback_next,
                        onPressed: _isLast
                            ? null
                            : () => context.read<PlaybackCubit>().skipNext(),
                      ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.target,
    required this.isPlaying,
    required this.isLoading,
  });
  final AyahIdentifier target;
  final bool isPlaying;
  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const SizedBox(
        width: 48,
        height: 48,
        child: Center(
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
        ),
      );
    }
    return IconButton(
      iconSize: 40,
      icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow),
      tooltip: isPlaying ? S.of(context).playback_pause : S.of(context).play,
      onPressed: () {
        final cubit = context.read<PlaybackCubit>();
        if (isPlaying) {
          cubit.pause();
        } else {
          cubit.playSelected(target);
        }
      },
    );
  }
}

class _SpeedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackCubit, PlaybackState>(
      buildWhen: (a, b) => a.speed != b.speed,
      builder: (context, state) {
        return PopupMenuButton<double>(
          tooltip: S.of(context).playback_speed,
          onSelected: (v) => context.read<PlaybackCubit>().setSpeed(v),
          itemBuilder: (_) => _speeds
              .map((s) => PopupMenuItem(value: s, child: Text('${s}x')))
              .toList(),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            child: Text('${state.speed}x'),
          ),
        );
      },
    );
  }
}
