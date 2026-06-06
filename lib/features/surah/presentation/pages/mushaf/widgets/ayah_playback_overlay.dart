import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as q;

import '../../../../../../generated/l10n.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../../quran_playback/domain/entities/reciter.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_state.dart';
import '../../../../../quran_playback/presentation/widgets/playback_repeat_options.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';

const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

/// Compact frosted-glass mini-player that floats over the Mushaf page without
/// pushing or resizing the content. Row layout keeps a fixed budget:
///   dismiss | [Expanded info] | ⏮ ▶ ⏭ | tune
/// Reciter and speed live in the tune sheet so the row never overflows.
class AyahPlaybackOverlay extends StatelessWidget {
  const AyahPlaybackOverlay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MushafCubit, MushafState>(
      buildWhen: (a, b) =>
          a.highlightedAyah != b.highlightedAyah ||
          a.isOverlayPinned != b.isOverlayPinned,
      builder: (context, mushafState) {
        final highlightTarget = mushafState.highlightedAyah;
        final isPinned = mushafState.isOverlayPinned;
        final visible = highlightTarget != null || isPinned;
        return Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: IgnorePointer(
            ignoring: !visible,
            child: AnimatedSlide(
              offset: visible ? Offset.zero : const Offset(0, 1),
              duration: const Duration(milliseconds: 260),
              curve: Curves.easeOutCubic,
              child: AnimatedOpacity(
                opacity: visible ? 1.0 : 0.0,
                duration: const Duration(milliseconds: 200),
                child: BlocBuilder<PlaybackCubit, PlaybackState>(
                  buildWhen: (a, b) => a.currentAyah != b.currentAyah,
                  builder: (context, playbackState) {
                    final effectiveTarget =
                        highlightTarget ?? playbackState.currentAyah;
                    return _MiniPlayer(target: effectiveTarget);
                  },
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini-player
// ─────────────────────────────────────────────────────────────────────────────

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({required this.target});
  final AyahIdentifier? target;

  bool get _isFirst =>
      target != null && target!.surah == 1 && target!.ayah == 1;
  bool get _isLast =>
      target != null &&
      target!.surah == 114 &&
      target!.ayah == q.getVerseCount(114);

  bool _currentMatchesTarget(AyahIdentifier? current, AyahIdentifier? t) {
    if (current == null || t == null) return false;
    if (current == t) return true;
    if (t.ayah == 0 && current.surah == t.surah && current.ayah == 1) {
      return true;
    }
    return false;
  }

  void _openReciterSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => BlocProvider.value(
        value: context.read<PlaybackCubit>(),
        child: const _ReciterSheet(),
      ),
    );
  }

  void _openOptionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: context.read<PlaybackCubit>(),
        child: const _OptionsSheet(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final s = S.of(context);
    return GestureDetector(
      // Swipe down to dismiss
      onVerticalDragEnd: (details) {
        if ((details.primaryVelocity ?? 0) > 300) {
          context.read<MushafCubit>().unpinOverlay();
        }
      },
      child: Padding(
      padding: EdgeInsets.fromLTRB(10, 0, 10, 10 + bottomPad),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(22),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black.withValues(alpha: 0.62),
              borderRadius: BorderRadius.circular(22),
            ),
            child: Row(
              children: [
                // ── Dismiss ──────────────────────────────────────────────
                _Btn(
                  icon: Icons.expand_more,
                  tooltip: s.playback_close,
                  onTap: () => context.read<MushafCubit>().unpinOverlay(),
                ),
                const SizedBox(width: 4),

                // ── Info column (ayah + reciter·speed subtitle) ──────────
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => _openReciterSheet(context),
                    child: _InfoColumn(target: target),
                  ),
                ),
                const SizedBox(width: 4),

                // ── Transport controls ────────────────────────────────────
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
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _Btn(
                          icon: Icons.skip_previous,
                          tooltip: s.playback_previous,
                          onTap: _isFirst
                              ? null
                              : () => context
                                  .read<PlaybackCubit>()
                                  .skipPrevious(),
                        ),
                        _PlayPauseBtn(
                          target: target,
                          isPlaying: isTargetPlaying,
                          isResumable: isResumable,
                          isLoading: p.isLoading,
                        ),
                        _Btn(
                          icon: Icons.skip_next,
                          tooltip: s.playback_next,
                          onTap: _isLast
                              ? null
                              : () =>
                                  context.read<PlaybackCubit>().skipNext(),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(width: 4),

                // ── Options (reciter / speed / repeat / range) ───────────
                _Btn(
                  icon: Icons.tune,
                  tooltip: s.playbackOptions,
                  onTap: () => _openOptionsSheet(context),
                ),
              ],
            ),
          ),
        ),
      ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Info column — ayah label + reciter·speed subtitle
// ─────────────────────────────────────────────────────────────────────────────

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.target});
  final AyahIdentifier? target;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (target != null)
          Text(
            s.ayah_label(
                target!.surah.toString(), target!.ayah.toString()),
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        // Reciter · speed · repeat indicator on one compact line
        BlocBuilder<PlaybackCubit, PlaybackState>(
          buildWhen: (a, b) =>
              a.reciter != b.reciter ||
              a.speed != b.speed ||
              a.eachAyahRepeat != b.eachAyahRepeat ||
              a.infiniteRepeat != b.infiniteRepeat ||
              a.currentAyahPlayCount != b.currentAyahPlayCount,
          builder: (context, p) {
            final repeatTxt = p.infiniteRepeat
                ? ' · ↻∞'
                : (p.eachAyahRepeat > 1
                    ? ' · ↻${p.currentAyahPlayCount}/${p.eachAyahRepeat}'
                    : '');
            final speedTxt =
                p.speed != 1.0 ? ' · ${p.speed}x' : '';
            return Text(
              '${p.reciter.arabicName}$speedTxt$repeatTxt',
              textAlign: TextAlign.center,
              style:
                  const TextStyle(color: Colors.white60, fontSize: 10),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            );
          },
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Reciter sheet — tap the info column to open
// ─────────────────────────────────────────────────────────────────────────────

class _ReciterSheet extends StatelessWidget {
  const _ReciterSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.of(context).reciter_label,
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 12),
            _ReciterRow(),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Options sheet — speed & repeat/range (tune icon)
// ─────────────────────────────────────────────────────────────────────────────

class _OptionsSheet extends StatelessWidget {
  const _OptionsSheet();

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(S.of(context).playback_speed,
                style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            _SpeedRow(),
            const SizedBox(height: 16),
            const PlaybackRepeatOptions(),
          ],
        ),
      ),
    );
  }
}

class _ReciterRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackCubit, PlaybackState>(
      buildWhen: (a, b) => a.reciter != b.reciter,
      builder: (context, state) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in Reciter.values)
              GestureDetector(
                onTap: () => context.read<PlaybackCubit>().setReciter(r),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: state.reciter == r
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    r.arabicName,
                    style: TextStyle(
                      fontSize: 13,
                      color: state.reciter == r
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

class _SpeedRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<PlaybackCubit, PlaybackState>(
      buildWhen: (a, b) => a.speed != b.speed,
      builder: (context, state) {
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final s in _speeds)
              GestureDetector(
                onTap: () => context.read<PlaybackCubit>().setSpeed(s),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 6),
                  decoration: BoxDecoration(
                    color: state.speed == s
                        ? Theme.of(context).colorScheme.primary
                        : Theme.of(context)
                            .colorScheme
                            .surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${s}x',
                    style: TextStyle(
                      fontSize: 13,
                      color: state.speed == s
                          ? Theme.of(context).colorScheme.onPrimary
                          : Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared icon button
// ─────────────────────────────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  const _Btn({
    required this.icon,
    required this.onTap,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;
  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    final iconColor = disabled ? Colors.white30 : Colors.white;
    final child = Icon(icon, color: iconColor, size: 20);
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(width: 36, height: 36, child: Center(child: child)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Play / Pause button
// ─────────────────────────────────────────────────────────────────────────────

class _PlayPauseBtn extends StatelessWidget {
  const _PlayPauseBtn({
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
        width: 44,
        height: 44,
        child: Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
                strokeWidth: 2.5, color: Colors.white),
          ),
        ),
      );
    }
    return GestureDetector(
      onTap: target == null
          ? null
          : () {
              final cubit = context.read<PlaybackCubit>();
              if (isPlaying) {
                cubit.pause();
              } else if (isResumable) {
                cubit.resume();
              } else {
                final t = target!;
                final start = t.ayah == 0
                    ? AyahIdentifier(surah: t.surah, ayah: 1)
                    : t;
                cubit.playRange(
                  start: start,
                  end: AyahIdentifier(
                      surah: t.surah, ayah: q.getVerseCount(t.surah)),
                );
              }
            },
      child: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: target == null
              ? Colors.white24
              : Theme.of(context).colorScheme.primary,
        ),
        child: Center(
          child: Icon(
            isPlaying ? Icons.pause : Icons.play_arrow,
            color: Colors.white,
            size: 24,
          ),
        ),
      ),
    );
  }
}
