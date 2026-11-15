import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/prayer_name.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_option_sheet.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/domain/entities/preview_sound.dart';
import 'package:quran_app/features/notifications/presentation/cubit/sound_preview_cubit.dart';
import 'package:quran_app/features/notifications/presentation/utils/enum_localization.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';

Future<void> showPrayerSoundPicker(BuildContext context, PrayerName prayer) {
  final s = PendingS.current;
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  final settings = context.read<SettingsCubit>();
  final current = _alertOf(settings, prayer).sound;
  final preview = ios ? null : sl<SoundPreviewCubit>();
  return showAppOptionSheet<PrayerSound>(
    context: context,
    title: s.alerts_picker_prayerSound,
    selected: ios && current == PrayerSound.vibrate
        ? PrayerSound.silent
        : current,
    options: [
      for (final sound in PrayerSound.values)
        if (!ios || sound != PrayerSound.vibrate)
          AppOption(
            value: sound,
            label: prayerSoundLabel(s, sound, prayer: prayer, ios: ios),
            subtitle: sound == PrayerSound.silent
                ? s.alerts_picker_silentSub
                : null,
            trailing: _previewTrailing(
              preview,
              switch (sound) {
                PrayerSound.adhan => PreviewSound.adhan,
                PrayerSound.tone => PreviewSound.tone,
                _ => null,
              },
              prayer,
              prayerSoundLabel(s, sound, prayer: prayer, ios: ios),
            ),
          ),
    ],
    onSelected: (sound) => settings.updatePrayerAlert(
      prayer,
      _alertOf(settings, prayer).copyWith(sound: sound),
    ),
    footer: _previewFooter(preview),
    onClosed: preview?.close,
  );
}

Future<void> showReminderSoundPicker(BuildContext context, PrayerName prayer) {
  final s = PendingS.current;
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  final settings = context.read<SettingsCubit>();
  final current = _alertOf(settings, prayer).reminderSound;
  final preview = ios ? null : sl<SoundPreviewCubit>();
  return showAppOptionSheet<ReminderSound>(
    context: context,
    title: s.alerts_sheet_reminderSound,
    selected: ios && current == ReminderSound.vibrate
        ? ReminderSound.silent
        : current,
    options: [
      for (final sound in ReminderSound.values)
        if (!ios || sound != ReminderSound.vibrate)
          AppOption(
            value: sound,
            label: reminderSoundLabel(s, sound, ios: ios),
            subtitle: sound == ReminderSound.silent
                ? s.alerts_picker_silentSub
                : null,
            trailing: _previewTrailing(
              preview,
              sound == ReminderSound.tone ? PreviewSound.tone : null,
              prayer,
              reminderSoundLabel(s, sound, ios: ios),
            ),
          ),
    ],
    onSelected: (sound) => settings.updatePrayerAlert(
      prayer,
      _alertOf(settings, prayer).copyWith(reminderSound: sound),
    ),
    footer: _previewFooter(preview),
    onClosed: preview?.close,
  );
}

PrayerAlert _alertOf(SettingsCubit settings, PrayerName prayer) =>
    settings.state.settingsModel.prayerAlerts[prayer] ?? const PrayerAlert();

Widget? _previewTrailing(
  SoundPreviewCubit? preview,
  PreviewSound? sound,
  PrayerName prayer,
  String label,
) {
  if (preview == null || sound == null) return null;
  return BlocProvider.value(
    value: preview,
    child: _PreviewButton(sound: sound, prayer: prayer, label: label),
  );
}

Widget? _previewFooter(SoundPreviewCubit? preview) => preview == null
    ? null
    : BlocProvider.value(value: preview, child: const _PreviewFooter());

class _PreviewButton extends StatelessWidget {
  const _PreviewButton({
    required this.sound,
    required this.prayer,
    required this.label,
  });

  final PreviewSound sound;
  final PrayerName prayer;
  final String label;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    return BlocSelector<SoundPreviewCubit, PreviewSound?, bool>(
      selector: (playing) => playing == sound,
      builder: (context, playing) => IconButton(
        constraints: const BoxConstraints(minWidth: 48, minHeight: 48),
        tooltip: playing
            ? s.alerts_picker_stopPreview
            : s.alerts_picker_preview(label),
        onPressed: () => context.read<SoundPreviewCubit>().play(sound, prayer),
        icon: HugeIcon(
          icon: playing
              ? HugeIcons.strokeRoundedStopCircle
              : HugeIcons.strokeRoundedPlayCircle,
          color: context.colorScheme.primary,
          size: 24,
        ),
      ),
    );
  }
}

class _PreviewFooter extends StatelessWidget {
  const _PreviewFooter();

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final previewing = PendingS.of(context).alerts_picker_previewing;
    return BlocSelector<SoundPreviewCubit, PreviewSound?, bool>(
      selector: (playing) => playing != null,
      builder: (context, playing) {
        if (!playing) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsetsDirectional.fromSTEB(24, 8, 24, 0),
          child: Column(
            spacing: 6,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const LinearProgressIndicator(minHeight: 2),
              Text(
                previewing,
                style: TS.regular12.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        );
      },
    );
  }
}
