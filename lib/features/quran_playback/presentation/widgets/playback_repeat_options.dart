import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/playback_range_validator.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/generated/l10n.dart';

/// Expanded playback panel: from→to range + per-ayah / per-range repeat counts
/// + an infinite toggle. Every counter is +/- steppable and tap-to-type.
class PlaybackRepeatOptions extends StatelessWidget {
  const PlaybackRepeatOptions({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
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
        return Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(s.range, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _Counter(
                    keyValue: 'range-from',
                    label: s.fromAyah,
                    value: from,
                    onChanged: (v) {
                      final nf = PlaybackRangeValidator.clampFrom(
                          surah: surah, value: v);
                      final nt = PlaybackRangeValidator.clampTo(
                          surah: surah, from: nf, value: to);
                      cubit.playRange(
                        start: AyahIdentifier(surah: surah, ayah: nf),
                        end: AyahIdentifier(surah: surah, ayah: nt),
                      );
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
                          surah: surah, from: from, value: v);
                      cubit.setRangeEnd(
                          AyahIdentifier(surah: surah, ayah: nt));
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(s.repeat, style: Theme.of(context).textTheme.labelMedium),
            const SizedBox(height: 6),
            Row(
              children: [
                Expanded(
                  child: _Counter(
                    keyValue: 'repeat-each',
                    label: s.eachAyah,
                    value: st.eachAyahRepeat,
                    onChanged: (v) => cubit.setEachAyahRepeat(
                        PlaybackRangeValidator.clampRepeat(v)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _Counter(
                    keyValue: 'repeat-range',
                    label: s.wholeRange,
                    value: st.rangeRepeat,
                    onChanged: (v) => cubit.setRangeRepeat(
                        PlaybackRangeValidator.clampRepeat(v)),
                  ),
                ),
                const SizedBox(width: 10),
                _InfiniteToggle(
                  on: st.infiniteRepeat,
                  onTap: () => cubit.setInfiniteRepeat(
                      !st.infiniteRepeat, RepeatTarget.range),
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
              final parsed =
                  PlaybackRangeValidator.parseCounter(controller.text);
              Navigator.pop(ctx, parsed); // null reverts to last valid
            },
            child: Text(S.of(context).filter_apply),
          ),
        ],
      ),
    );
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
                  Text('$value',
                      style: Theme.of(context).textTheme.titleMedium),
                  Text(label,
                      style: Theme.of(context).textTheme.labelSmall),
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
  const _InfiniteToggle({required this.on, required this.onTap});
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return GestureDetector(
      key: const ValueKey('repeat-infinite'),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: on ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(
          '∞',
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.bold,
            color: on ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}
