import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as q;

import '../../../../../../generated/l10n.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../../quran_playback/domain/entities/reciter.dart';
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
      buildWhen: (a, b) =>
          a.highlightedAyah != b.highlightedAyah ||
          a.highlightedAyahCenterY != b.highlightedAyahCenterY ||
          a.isOverlayPinned != b.isOverlayPinned,
      builder: (context, mushafState) {
        final highlightTarget = mushafState.highlightedAyah;
        final isPinned = mushafState.isOverlayPinned;
        final visible = highlightTarget != null || isPinned;
        final centerY = mushafState.highlightedAyahCenterY;
        final anchorTop = centerY != null && centerY > 0.5;
        return Positioned(
          left: 0,
          right: 0,
          top: anchorTop ? 0 : null,
          bottom: anchorTop ? null : 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedSlide(
              offset: visible
                  ? Offset.zero
                  : Offset(0, anchorTop ? -1 : 1),
              duration: const Duration(milliseconds: 200),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 180),
                child: visible
                    ? BlocBuilder<PlaybackCubit, PlaybackState>(
                        buildWhen: (a, b) => a.currentAyah != b.currentAyah,
                        builder: (context, playbackState) {
                          final effectiveTarget =
                              highlightTarget ?? playbackState.currentAyah;
                          return _Body(target: effectiveTarget);
                        },
                      )
                    : const SizedBox.shrink(),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.target});
  final AyahIdentifier? target;

  bool get _isFirst =>
      target != null && target!.surah == 1 && target!.ayah == 1;
  bool get _isLast =>
      target != null &&
      target!.surah == 114 &&
      target!.ayah == q.getVerseCount(114);

  bool _currentMatchesTarget(
      AyahIdentifier? current, AyahIdentifier? target) {
    if (current == null || target == null) return false;
    if (current == target) return true;
    if (target.ayah == 0 &&
        current.surah == target.surah &&
        current.ayah == 1) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Material(
      elevation: 8,
      color: scheme.surfaceContainerHighest,
      borderRadius: const BorderRadius.all(Radius.circular(16)),
      child: Padding(
        padding: const EdgeInsetsDirectional.symmetric(
            horizontal: 8, vertical: 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.expand_more),
                  tooltip: s.playback_close,
                  onPressed: () =>
                      context.read<MushafCubit>().unpinOverlay(),
                ),
                Expanded(
                  child: Text(
                    target != null
                        ? s.ayah_label(
                            target!.surah.toString(),
                            target!.ayah.toString())
                        : '',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                ),
                _ReciterChip(),
                _SpeedChip(),
              ],
            ),
            BlocBuilder<PlaybackCubit, PlaybackState>(
              buildWhen: (a, b) =>
                  a.isPlaying != b.isPlaying ||
                  a.isPaused != b.isPaused ||
                  a.isLoading != b.isLoading ||
                  a.currentAyah != b.currentAyah,
              builder: (context, p) {
                final matchesTarget =
                    _currentMatchesTarget(p.currentAyah, target);
                final isTargetPlaying = p.isPlaying && matchesTarget;
                final isResumable = p.isPaused && matchesTarget;
                return Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.skip_previous),
                      tooltip: s.playback_previous,
                      onPressed: _isFirst
                          ? null
                          : () =>
                              context.read<PlaybackCubit>().skipPrevious(),
                    ),
                    IconButton(
                      icon: const Icon(Icons.replay),
                      tooltip: s.playback_restart,
                      onPressed: p.currentAyah == null
                          ? null
                          : () => context
                              .read<PlaybackCubit>()
                              .restartCurrent(),
                    ),
                    _PlayPauseButton(
                      target: target,
                      isPlaying: isTargetPlaying,
                      isResumable: isResumable,
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
    );
  }
}

class _PlayPauseButton extends StatelessWidget {
  const _PlayPauseButton({
    required this.target,
    required this.isPlaying,
    required this.isResumable,
    required this.isLoading,
  });
  final AyahIdentifier? target;
  final bool isPlaying;
  final bool isResumable;
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
      onPressed: target == null
          ? null
          : () {
              final cubit = context.read<PlaybackCubit>();
              if (isPlaying) {
                cubit.pause();
              } else if (isResumable) {
                cubit.resume();
              } else {
                cubit.playSelected(target!);
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

class _ReciterChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackCubit, PlaybackState>(
      buildWhen: (a, b) => a.reciter != b.reciter,
      builder: (context, state) {
        return PopupMenuButton<Reciter>(
          tooltip: S.of(context).reciter_label,
          onSelected: (r) => context.read<PlaybackCubit>().setReciter(r),
          itemBuilder: (_) => [
            for (final r in Reciter.values)
              PopupMenuItem(value: r, child: Text(r.arabicName)),
          ],
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.record_voice_over, size: 16),
                const SizedBox(width: 4),
                Flexible(
                  child: Text(
                    state.reciter.arabicName,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.labelMedium,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
