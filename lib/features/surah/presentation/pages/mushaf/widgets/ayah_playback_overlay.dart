import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as q;

import '../../../../../../config/theme/typography_styles.dart';
import '../../../../../../core/helper functions/locale_helpers.dart';
import '../../../../../../core/localization/pending_s.dart';
import '../../../../../../generated/l10n.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_state.dart';
import '../../../../../quran_playback/presentation/cubit/surah_download/surah_download_cubit.dart';
import '../../../../../quran_playback/presentation/widgets/playback_options_sheet.dart';
import '../../../../../settings/presentation/cubit/settings_cubit.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';

const _playerClearance = 76.0;

/// Compact frosted-glass mini-player that floats over the Mushaf page without
/// pushing or resizing the content.
///
/// Sheet-opening callbacks are owned by [AyahPlaybackOverlay] (outer BlocBuilder
/// context — stable, rebuilt only on ayah-selection changes) rather than by
/// [_MiniPlayer] (inner BlocBuilder context — rebuilt on every ayah advance
/// during playback). This prevents "deactivated context" overlay crashes.
class AyahPlaybackOverlay extends StatefulWidget {
  const AyahPlaybackOverlay({super.key});

  @override
  State<AyahPlaybackOverlay> createState() => _AyahPlaybackOverlayState();
}

class _AyahPlaybackOverlayState extends State<AyahPlaybackOverlay> {
  ScaffoldFeatureController<SnackBar, SnackBarClosedReason>? _snack;
  ScaffoldMessengerState? _messenger;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _messenger = ScaffoldMessenger.maybeOf(context);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final playback = context.read<PlaybackCubit>().state;
      if (playback.playedFromNetwork && playback.skipOrigin != null) {
        _showDownloadHint(context, playback);
      }
    });
  }

  @override
  void dispose() {
    final messenger = _messenger;
    if (_snack != null && messenger != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (messenger.mounted) messenger.removeCurrentSnackBar();
      });
    }
    super.dispose();
  }

  void _openOptionsSheet(BuildContext context) {
    // If the options sheet is opened before playback has started (user tapped
    // an ayah but hasn't pressed play), seed the range from the highlighted
    // ayah so PlaybackRepeatOptions shows the correct surah instead of
    // defaulting to Al-Fatiha (surah 1).
    final playback = context.read<PlaybackCubit>().state;
    if (playback.rangeStart == null && playback.currentAyah == null) {
      final highlighted = context.read<MushafCubit>().state.selectedAyah;
      if (highlighted != null) {
        final surah = highlighted.surah;
        context.read<PlaybackCubit>().setRange(
          start: AyahIdentifier(surah: surah, ayah: highlighted.realAyah),
          end: AyahIdentifier(surah: surah, ayah: q.getVerseCount(surah)),
        );
      }
    }
    PlaybackOptionsSheet.show(
      context,
      onNewPlay: context.read<MushafCubit>().resumeFollow,
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MushafCubit, MushafState>(
      buildWhen: (a, b) =>
          a.selectedAyah != b.selectedAyah ||
          a.isOverlayPinned != b.isOverlayPinned,
      builder: (stableCtx, mushafState) {
        // stableCtx only rebuilds on ayah-selection / pin changes — safe to
        // capture in sheet callbacks without risking a deactivated-context crash.
        final selected = mushafState.selectedAyah;
        final isPinned = mushafState.isOverlayPinned;

        return BlocSelector<PlaybackCubit, PlaybackState, bool>(
          selector: (p) => (p.requestedAyah ?? p.currentAyah) != null,
          builder: (_, active) {
            final visible = selected != null || isPinned || active;
            return Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: MultiBlocListener(
                listeners: [
                  BlocListener<PlaybackCubit, PlaybackState>(
                    listenWhen: (a, b) => b.error != null && a.error != b.error,
                    listener: _showAudioError,
                  ),
                  BlocListener<PlaybackCubit, PlaybackState>(
                    listenWhen: (a, b) =>
                        ((a.requestedAyah ?? a.currentAyah) != null &&
                            (b.requestedAyah ?? b.currentAyah) == null) ||
                        (a.error != null && b.error == null),
                    listener: (_, _) => _removeSnack(),
                  ),
                  BlocListener<MushafCubit, MushafState>(
                    listenWhen: (a, b) =>
                        a.followPlayback &&
                        !b.followPlayback &&
                        b.playingAyah != null,
                    listener: _showNowReciting,
                  ),
                  BlocListener<MushafCubit, MushafState>(
                    listenWhen: (a, b) => !a.followPlayback && b.followPlayback,
                    listener: (_, _) => _removeSnack(),
                  ),
                  BlocListener<PlaybackCubit, PlaybackState>(
                    listenWhen: (a, b) =>
                        !a.playedFromNetwork && b.playedFromNetwork,
                    listener: _showDownloadHint,
                  ),
                ],
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
                        buildWhen: (a, b) =>
                            a.currentAyah != b.currentAyah ||
                            a.requestedAyah != b.requestedAyah,
                        builder: (_, playbackState) => _MiniPlayer(
                          target:
                              selected ??
                              playbackState.requestedAyah ??
                              playbackState.currentAyah,
                          active: active,
                          onTapInfo: () => _openOptionsSheet(stableCtx),
                          onTapTune: () => _openOptionsSheet(stableCtx),
                          onDismiss: () =>
                              stableCtx.read<MushafCubit>().unpinOverlay(),
                          onEnd: () {
                            stableCtx.read<PlaybackCubit>().stop();
                            stableCtx.read<MushafCubit>().unpinOverlay();
                          },
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }

  ScaffoldFeatureController<SnackBar, SnackBarClosedReason> _showSnack(
    BuildContext context,
    String text,
    String label,
    VoidCallback onPressed, {
    required bool persist,
  }) {
    _removeSnack();
    final controller = ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(text, style: TS.regular14),
        behavior: SnackBarBehavior.floating,
        persist: persist,
        margin: EdgeInsetsDirectional.fromSTEB(
          16,
          0,
          16,
          _playerClearance + MediaQuery.of(context).padding.bottom,
        ),
        action: SnackBarAction(label: label, onPressed: onPressed),
      ),
    );
    _snack = controller;
    controller.closed.whenComplete(() {
      if (_snack == controller) _snack = null;
    });
    return controller;
  }

  void _removeSnack() {
    if (_snack == null) return;
    _snack = null;
    _messenger?.removeCurrentSnackBar();
  }

  void _showAudioError(BuildContext context, PlaybackState state) {
    final ayah = (state.requestedAyah ?? state.currentAyah)!;
    final pending = PendingS.current;
    _showSnack(
      context,
      pending.mushaf_audioError(
        surahDisplayName(context, ayah.surah),
        ayah.realAyah.toLocalized(context),
      ),
      pending.mushaf_retry,
      context.read<PlaybackCubit>().retry,
      persist: true,
    );
  }

  void _showDownloadHint(BuildContext context, PlaybackState state) {
    final settings = context.read<SettingsCubit>();
    if (settings.state.settingsModel.downloadHintSeen) return;
    final downloads = context.read<SurahDownloadCubit>();
    final surah = state.skipOrigin!.surah;
    final pending = PendingS.current;
    final controller = _showSnack(
      context,
      pending.surahDownload_hint,
      pending.surahDownload_download,
      () => downloads.download(state.reciter, surah),
      persist: false,
    );
    controller.closed.then((reason) {
      if (reason != SnackBarClosedReason.hide &&
          reason != SnackBarClosedReason.remove) {
        settings.markDownloadHintSeen();
      }
    });
  }

  void _showNowReciting(BuildContext context, MushafState state) {
    final mushaf = context.read<MushafCubit>();
    final ayah = state.playingAyah!;
    final pending = PendingS.current;
    _showSnack(
      context,
      pending.mushaf_nowReciting(
        surahDisplayName(context, ayah.surah),
        ayah.realAyah.toLocalized(context),
        mushaf.playingPage!.toLocalized(context),
      ),
      pending.mushaf_returnToReciting,
      () {
        if (!mushaf.isClosed) mushaf.resumeFollow();
      },
      persist: false,
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Mini-player
// ─────────────────────────────────────────────────────────────────────────────

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    required this.target,
    required this.active,
    required this.onTapInfo,
    required this.onTapTune,
    required this.onDismiss,
    required this.onEnd,
  });

  final AyahIdentifier? target;
  final bool active;
  final VoidCallback onTapInfo;
  final VoidCallback onTapTune;
  final VoidCallback onDismiss;
  final VoidCallback onEnd;

  bool _currentMatchesTarget(AyahIdentifier? current, AyahIdentifier? t) {
    if (current == null || t == null) return false;
    if (current == t) return true;
    if (t.ayah == 0 && current.surah == t.surah && current.ayah == 1) {
      return true;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.of(context).padding.bottom;
    final s = S.of(context);
    return GestureDetector(
      onVerticalDragEnd: (details) {
        if (!active && (details.primaryVelocity ?? 0) > 300) onDismiss();
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
                  // ── Dismiss ────────────────────────────────────────────
                  _Btn(
                    icon: active ? Icons.stop : Icons.expand_more,
                    tooltip: active
                        ? PendingS.of(context).mushaf_endRecitation
                        : s.playback_close,
                    onTap: active ? onEnd : onDismiss,
                  ),
                  const SizedBox(width: 4),

                  // ── Info (tap → reciter sheet) ─────────────────────────
                  Expanded(
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: onTapInfo,
                      child: _InfoColumn(target: target),
                    ),
                  ),
                  const SizedBox(width: 4),

                  // ── Transport controls ─────────────────────────────────
                  BlocBuilder<PlaybackCubit, PlaybackState>(
                    buildWhen: (a, b) =>
                        a.isPlaying != b.isPlaying ||
                        a.isPaused != b.isPaused ||
                        a.isLoading != b.isLoading ||
                        a.currentAyah != b.currentAyah ||
                        a.rangeStart != b.rangeStart ||
                        a.rangeEnd != b.rangeEnd ||
                        a.requestedAyah != b.requestedAyah,
                    builder: (context, p) {
                      final matchesTarget = _currentMatchesTarget(
                        p.currentAyah,
                        target,
                      );
                      final isTargetPlaying = p.isPlaying && matchesTarget;
                      final isResumable = p.isPaused && matchesTarget;
                      return Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _Btn(
                            icon: Icons.skip_previous,
                            tooltip: s.playback_previous,
                            onTap: p.canSkipPrevious
                                ? () {
                                    context
                                        .read<PlaybackCubit>()
                                        .skipPrevious();
                                    context.read<MushafCubit>().resumeFollow();
                                  }
                                : null,
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
                            onTap: p.canSkipNext
                                ? () {
                                    context.read<PlaybackCubit>().skipNext();
                                    context.read<MushafCubit>().resumeFollow();
                                  }
                                : null,
                          ),
                        ],
                      );
                    },
                  ),
                  const SizedBox(width: 4),

                  // ── Options (tap → speed + repeat sheet) ──────────────
                  _Btn(
                    icon: Icons.tune,
                    tooltip: s.playbackOptions,
                    onTap: onTapTune,
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
// Info column — ayah label + reciter · speed · repeat subtitle
// ─────────────────────────────────────────────────────────────────────────────

class _InfoColumn extends StatelessWidget {
  const _InfoColumn({required this.target});
  final AyahIdentifier? target;

  @override
  Widget build(BuildContext context) {
    final target = this.target;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (target != null)
          Text(
            S
                .of(context)
                .ayah_label(
                  surahDisplayName(context, target.surah),
                  target.realAyah.toLocalized(context),
                ),
            textAlign: TextAlign.center,
            style: TS.semi12.copyWith(color: Colors.white),
            overflow: TextOverflow.ellipsis,
          ),
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
                      ? ' · ↻${p.currentAyahPlayCount.toLocalized(context)}/${p.eachAyahRepeat.toLocalized(context)}'
                      : '');
            final speedTxt = p.speed != 1.0
                ? ' · ${p.speed.toLocalized(context)}x'
                : '';
            return Text(
              '${p.reciter.arabicName}$speedTxt$repeatTxt',
              textAlign: TextAlign.center,
              style: TS.regular10.copyWith(color: Colors.white60),
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
// Shared icon button
// ─────────────────────────────────────────────────────────────────────────────

class _Btn extends StatelessWidget {
  const _Btn({required this.icon, required this.onTap, this.tooltip});
  final IconData icon;
  final VoidCallback? onTap;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    final color = onTap == null ? Colors.white30 : Colors.white;
    return Tooltip(
      message: tooltip ?? '',
      child: GestureDetector(
        onTap: onTap,
        child: SizedBox(
          width: 36,
          height: 36,
          child: Center(child: Icon(icon, color: color, size: 20)),
        ),
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
              strokeWidth: 2.5,
              color: Colors.white,
            ),
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
              } else if (isResumable || cubit.state.error != null) {
                cubit.resume();
              } else {
                final t = target!;
                final start = t.ayah == 0
                    ? AyahIdentifier(surah: t.surah, ayah: 1)
                    : t;
                cubit.playRange(
                  start: start,
                  end: AyahIdentifier(
                    surah: t.surah,
                    ayah: q.getVerseCount(t.surah),
                  ),
                );
                context.read<MushafCubit>().resumeFollow();
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
