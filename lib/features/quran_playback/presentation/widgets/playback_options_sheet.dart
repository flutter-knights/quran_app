import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/quran_playback/presentation/widgets/playback_repeat_options.dart';
import 'package:quran_app/generated/l10n.dart';

const _speeds = [0.5, 0.75, 1.0, 1.25, 1.5, 2.0];

String _speedLabel(BuildContext context, double speed) {
  final raw = speed == speed.truncateToDouble()
      ? speed.toInt().toString()
      : speed.toString();
  return '${(context.isArabic ? raw.replaceAll('.', '٫') : raw).toLocalized(context)}×';
}

class PlaybackOptionsSheet extends StatelessWidget {
  const PlaybackOptionsSheet({super.key, this.onNewPlay});

  final VoidCallback? onNewPlay;

  static Future<void> show(BuildContext context, {VoidCallback? onNewPlay}) {
    final playback = context.read<PlaybackCubit>();
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => BlocProvider.value(
        value: playback,
        child: PlaybackOptionsSheet(onNewPlay: onNewPlay),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 12,
          children: [
            Text(PendingS.of(context).player_optionsTitle, style: TS.bold16),
            Text(s.reciter_label, style: TS.medium14),
            const _ReciterGrid(),
            Text(s.playback_speed, style: TS.medium14),
            const _SpeedGrid(),
            PlaybackRepeatOptions(onNewPlay: onNewPlay),
          ],
        ),
      ),
    );
  }
}

class _ReciterGrid extends StatelessWidget {
  const _ReciterGrid();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<PlaybackCubit, PlaybackState>(
        buildWhen: (a, b) => a.reciter != b.reciter,
        builder: (context, state) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final r in Reciter.values)
              _OptionChip(
                label: r.arabicName,
                selected: state.reciter == r,
                onTap: () => context.read<PlaybackCubit>().setReciter(r),
              ),
          ],
        ),
      );
}

class _SpeedGrid extends StatelessWidget {
  const _SpeedGrid();

  @override
  Widget build(BuildContext context) =>
      BlocBuilder<PlaybackCubit, PlaybackState>(
        buildWhen: (a, b) => a.speed != b.speed,
        builder: (context, state) => Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final speed in _speeds)
              _OptionChip(
                label: _speedLabel(context, speed),
                selected: state.speed == speed,
                onTap: () => context.read<PlaybackCubit>().setSpeed(speed),
              ),
          ],
        ),
      );
}

class _OptionChip extends StatelessWidget {
  const _OptionChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Semantics(
      button: true,
      selected: selected,
      excludeSemantics: true,
      label: label,
      onTap: onTap,
      child: PrettierTap(
        onTap: onTap,
        child: AnimatedContainer(
          key: const ValueKey('option-chip'),
          duration: const Duration(milliseconds: 180),
          constraints: const BoxConstraints(minHeight: 48, minWidth: 48),
          alignment: Alignment.center,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: selected ? scheme.primary : scheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Text(
            label,
            style: TS.regular14.copyWith(
              color: selected ? scheme.onPrimary : scheme.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
