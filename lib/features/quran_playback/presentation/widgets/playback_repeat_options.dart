import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/playback_range_validator.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/generated/l10n.dart';

/// Expanded playback panel: from→to range + per-ayah / per-range repeat counts
/// + an infinite toggle. Every counter is +/- steppable and tap-to-type.
class PlaybackRepeatOptions extends StatelessWidget {
  const PlaybackRepeatOptions({super.key, this.onNewPlay});

  final VoidCallback? onNewPlay;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final pending = PendingS.of(context);
    return BlocBuilder<PlaybackCubit, PlaybackState>(
      buildWhen: (a, b) =>
          a.rangeStart != b.rangeStart ||
          a.rangeEnd != b.rangeEnd ||
          a.eachAyahRepeat != b.eachAyahRepeat ||
          a.rangeRepeat != b.rangeRepeat ||
          a.infiniteRepeat != b.infiniteRepeat ||
          a.infiniteTarget != b.infiniteTarget,
      builder: (context, st) {
        final cubit = context.read<PlaybackCubit>();
        final surah = st.rangeStart?.surah ?? st.currentAyah?.surah ?? 1;
        final from = st.rangeStart?.ayah ?? st.currentAyah?.ayah ?? 1;
        final to = st.rangeEnd?.ayah ?? quran.getVerseCount(surah);
        final start = st.rangeStart;
        final end = st.rangeEnd;
        final crossSurah =
            start != null && end != null && start.surah != end.surah;
        String endLabel(AyahIdentifier a) =>
            '${surahDisplayName(context, a.surah)} ${a.ayah.toLocalized(context)}';
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.range, style: TS.medium12),
            const SizedBox(height: 6),
            if (crossSurah)
              Text(
                pending.playback_crossSurahRange(
                  endLabel(start),
                  endLabel(end),
                ),
                style: TS.medium14,
              )
            else
              Row(
                children: [
                  Expanded(
                    child: _Counter(
                      keyValue: 'range-from',
                      label: s.fromAyah,
                      value: from,
                      onChanged: (v) {
                        final nf = PlaybackRangeValidator.clampFrom(
                          surah: surah,
                          value: v,
                        );
                        final nt = PlaybackRangeValidator.clampTo(
                          surah: surah,
                          from: nf,
                          value: to,
                        );
                        cubit.playRange(
                          start: AyahIdentifier(surah: surah, ayah: nf),
                          end: AyahIdentifier(surah: surah, ayah: nt),
                        );
                        onNewPlay?.call();
                      },
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Counter(
                      keyValue: 'range-to',
                      label: s.toAyah,
                      value: to,
                      onChanged: (v) {
                        final nt = PlaybackRangeValidator.clampTo(
                          surah: surah,
                          from: from,
                          value: v,
                        );
                        cubit.setRangeEnd(
                          AyahIdentifier(surah: surah, ayah: nt),
                        );
                      },
                    ),
                  ),
                ],
              ),
            const SizedBox(height: 16),
            Text(s.repeat, style: TS.medium12),
            const SizedBox(height: 6),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: _Counter(
                    keyValue: 'repeat-each',
                    label: pending.playback_repeatEachAyah,
                    value: st.eachAyahRepeat,
                    onChanged: (v) => cubit.setEachAyahRepeat(
                      PlaybackRangeValidator.clampRepeat(v),
                    ),
                  ),
                ),
                _InfiniteToggle(
                  keyValue: 'repeat-infinite-each',
                  on:
                      st.infiniteRepeat &&
                      st.infiniteTarget == RepeatTarget.eachAyah,
                  onTap: () => cubit.setInfiniteRepeat(
                    !(st.infiniteRepeat &&
                        st.infiniteTarget == RepeatTarget.eachAyah),
                    RepeatTarget.eachAyah,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              spacing: 10,
              children: [
                Expanded(
                  child: _Counter(
                    keyValue: 'repeat-range',
                    label: pending.playback_repeatPassage,
                    value: st.rangeRepeat,
                    onChanged: (v) => cubit.setRangeRepeat(
                      PlaybackRangeValidator.clampRepeat(v),
                    ),
                  ),
                ),
                _InfiniteToggle(
                  keyValue: 'repeat-infinite-range',
                  on:
                      st.infiniteRepeat &&
                      st.infiniteTarget == RepeatTarget.range,
                  onTap: () => cubit.setInfiniteRepeat(
                    !(st.infiniteRepeat &&
                        st.infiniteTarget == RepeatTarget.range),
                    RepeatTarget.range,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}

class _Counter extends StatelessWidget {
  const _Counter({
    required this.keyValue,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String keyValue;
  final String label;
  final int value;
  final ValueChanged<int> onChanged;

  Future<void> _typeValue(BuildContext context) async {
    final controller = TextEditingController(text: value.toString());
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        content: TextField(
          key: const ValueKey('counter-text-field'),
          controller: controller,
          autofocus: true,
          keyboardType: TextInputType.number,
        ),
        actions: [
          TextButton(
            onPressed: () {
              final parsed = PlaybackRangeValidator.parseCounter(
                controller.text,
              );
              Navigator.pop(ctx, parsed); // null reverts to last valid
            },
            child: Text(S.of(context).filter_apply, style: TS.medium14),
          ),
        ],
      ),
    );
    // Schedule dispose after the dialog's close animation has completed so
    // the framework never touches a disposed controller during tear-down.
    WidgetsBinding.instance.addPostFrameCallback((_) => controller.dispose());
    if (result != null) onChanged(result);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      key: ValueKey(keyValue),
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.remove, size: 18),
            onPressed: () => onChanged(value - 1),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => _typeValue(context),
              child: Column(
                children: [
                  Text(value.toLocalized(context), style: TS.medium16),
                  Text(label, style: TS.medium12),
                ],
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.add, size: 18),
            onPressed: () => onChanged(value + 1),
          ),
        ],
      ),
    );
  }
}

class _InfiniteToggle extends StatelessWidget {
  const _InfiniteToggle({
    required this.keyValue,
    required this.on,
    required this.onTap,
  });
  final String keyValue;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      key: ValueKey(keyValue),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: on ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '∞',
          style: TS.bold20.copyWith(
            color: on ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
