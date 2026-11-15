import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/palette_context.dart';
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
  final settings = context.read<SettingsCubit>();
  return _showSoundPicker(
    context: context,
    prayer: prayer,
    title: PendingS.current.alerts_picker_prayerSound,
    values: PrayerSound.values,
    current: _alertOf(settings, prayer).sound,
    vibrate: PrayerSound.vibrate,
    silent: PrayerSound.silent,
    labelOf: (sound, ios) =>
        prayerSoundLabel(PendingS.current, sound, prayer: prayer, ios: ios),
    previewOf: (sound) => switch (sound) {
      PrayerSound.adhan => PreviewSound.adhan,
      PrayerSound.tone => PreviewSound.tone,
      _ => null,
    },
    onSelected: (sound) => settings.updatePrayerAlert(
      prayer,
      _alertOf(settings, prayer).copyWith(sound: sound),
    ),
  );
}

Future<void> showReminderSoundPicker(BuildContext context, PrayerName prayer) {
  final settings = context.read<SettingsCubit>();
  return _showSoundPicker(
    context: context,
    prayer: prayer,
    title: PendingS.current.alerts_sheet_reminderSound,
    values: ReminderSound.values,
    current: _alertOf(settings, prayer).reminderSound,
    vibrate: ReminderSound.vibrate,
    silent: ReminderSound.silent,
    labelOf: (sound, ios) =>
        reminderSoundLabel(PendingS.current, sound, ios: ios),
    previewOf: (sound) =>
        sound == ReminderSound.tone ? PreviewSound.tone : null,
    onSelected: (sound) => settings.updatePrayerAlert(
      prayer,
      _alertOf(settings, prayer).copyWith(reminderSound: sound),
    ),
  );
}

Future<void> _showSoundPicker<T>({
  required BuildContext context,
  required PrayerName prayer,
  required String title,
  required List<T> values,
  required T current,
  required T vibrate,
  required T silent,
  required String Function(T sound, bool ios) labelOf,
  required PreviewSound? Function(T sound) previewOf,
  required ValueChanged<T> onSelected,
}) {
  final s = PendingS.current;
  final ios = defaultTargetPlatform == TargetPlatform.iOS;
  final preview = ios ? null : sl<SoundPreviewCubit>();
  return showAppOptionSheet(
    context: context,
    title: title,
    selected: ios && current == vibrate ? silent : current,
    options: values.where((sound) => !ios || sound != vibrate).map((sound) {
      final label = labelOf(sound, ios);
      return AppOption(
        value: sound,
        label: label,
        subtitle: sound == silent ? s.alerts_picker_silentSub : null,
        trailing: _previewTrailing(preview, previewOf(sound), prayer, label),
      );
    }).toList(),
    onSelected: onSelected,
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
    final ink = context.palette.primaryInk;
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
          color: ink,
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
