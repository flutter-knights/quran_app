import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/presentation/utils/enum_localization.dart';
import 'package:quran_app/features/onboarding/presentation/pages/widgets/onboarding_step_header.dart';
import 'package:quran_app/features/onboarding/presentation/utils/apply_alerts_choice.dart';

class AlertsStep extends StatelessWidget {
  const AlertsStep({super.key, required this.choice, required this.onChanged});

  static const reminderOptions = [5, 10, 15, 30];

  final AlertsChoice choice;
  final ValueChanged<AlertsChoice> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final lang = context.langCode;
    final alertOn = choice.sound != null;
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(22, 8, 22, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingStepHeader(
            icon: HugeIcons.strokeRoundedNotification01,
            title: s.onb_alerts_title,
          ),
          _Label(s.onb_alerts_atTime),
          RadioGroup<PrayerSound?>(
            groupValue: choice.sound,
            onChanged: _pickSound,
            child: Column(
              spacing: 8,
              children: [
                _SoundCard(
                  value: PrayerSound.adhan,
                  label: s.alerts_sound_adhan,
                  selected: choice.sound == PrayerSound.adhan,
                  onTap: _pickSound,
                ),
                _SoundCard(
                  value: PrayerSound.tone,
                  label: s.alerts_sound_tone,
                  selected: choice.sound == PrayerSound.tone,
                  onTap: _pickSound,
                ),
                _SoundCard(
                  value: null,
                  label: s.onb_alerts_none,
                  selected: !alertOn,
                  onTap: _pickSound,
                ),
              ],
            ),
          ),
          _Label(s.onb_alerts_reminder),
          Theme(
            data: Theme.of(context).copyWith(canvasColor: Colors.transparent),
            child: Opacity(
              opacity: alertOn ? 1 : 0.38,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _ReminderChip(
                    label: s.onb_alerts_reminderNone,
                    selected: choice.reminderMinutes == null,
                    onSelected: alertOn ? () => _pickMinutes(null) : null,
                  ),
                  for (final m in reminderOptions)
                    _ReminderChip(
                      label: minutesLabel(s, m, lang),
                      selected: choice.reminderMinutes == m,
                      onSelected: alertOn ? () => _pickMinutes(m) : null,
                    ),
                ],
              ),
            ),
          ),
          if (defaultTargetPlatform == TargetPlatform.android) ...[
            const SizedBox(height: 18),
            _SwitchCard(
              children: [
                _SwitchRow(
                  label: s.alerts_sheet_ringInSilent,
                  value:
                      choice.ringInSilent && choice.sound == PrayerSound.adhan,
                  onChanged: choice.sound == PrayerSound.adhan
                      ? (v) => onChanged(choice.copyWith(ringInSilent: v))
                      : null,
                ),
                _SwitchRow(
                  label: s.strip_title,
                  value: choice.stripPinned,
                  onChanged: (v) => onChanged(choice.copyWith(stripPinned: v)),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  void _pickSound(PrayerSound? sound) => onChanged(
    AlertsChoice(
      sound: sound,
      reminderMinutes: choice.reminderMinutes,
      ringInSilent: choice.ringInSilent,
      stripPinned: choice.stripPinned,
    ),
  );

  void _pickMinutes(int? minutes) => onChanged(
    AlertsChoice(
      sound: choice.sound,
      reminderMinutes: minutes,
      ringInSilent: choice.ringInSilent,
      stripPinned: choice.stripPinned,
    ),
  );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(2, 18, 2, 10),
      child: Text(
        text,
        style: TS.semi14.copyWith(color: Colors.white.withValues(alpha: 0.75)),
      ),
    );
  }
}

class _SoundCard extends StatelessWidget {
  const _SoundCard({
    required this.value,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final PrayerSound? value;
  final String label;
  final bool selected;
  final ValueChanged<PrayerSound?> onTap;

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    final fg = selected ? primary : Colors.white;
    return Material(
      color: selected ? Colors.white : Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(
          color: Colors.white.withValues(alpha: selected ? 1 : 0.2),
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => onTap(value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 4, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(label, style: TS.semi16.copyWith(color: fg)),
                ),
                Radio<PrayerSound?>(
                  value: value,
                  fillColor: WidgetStatePropertyAll(fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ReminderChip extends StatelessWidget {
  const _ReminderChip({
    required this.label,
    required this.selected,
    required this.onSelected,
  });

  final String label;
  final bool selected;
  final VoidCallback? onSelected;

  @override
  Widget build(BuildContext context) {
    final primary = context.colorScheme.primary;
    final onSelected = this.onSelected;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      showCheckmark: false,
      materialTapTargetSize: MaterialTapTargetSize.padded,
      labelStyle: TS.semi14.copyWith(color: selected ? primary : Colors.white),
      backgroundColor: Colors.white.withValues(alpha: 0.08),
      selectedColor: Colors.white,
      disabledColor: Colors.white.withValues(alpha: selected ? 1 : 0.08),
      side: BorderSide(
        color: Colors.white.withValues(alpha: selected ? 1 : 0.2),
      ),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      onSelected: onSelected == null ? null : (_) => onSelected(),
    );
  }
}

class _SwitchCard extends StatelessWidget {
  const _SwitchCard({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white.withValues(alpha: 0.08),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: Colors.white.withValues(alpha: 0.2)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        children: [
          for (final (i, child) in children.indexed) ...[
            if (i > 0)
              Divider(height: 1, color: Colors.white.withValues(alpha: 0.2)),
            child,
          ],
        ],
      ),
    );
  }
}

class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.label,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final onChanged = this.onChanged;
    return MergeSemantics(
      child: InkWell(
        onTap: onChanged == null ? null : () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 56),
          child: Padding(
            padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style: TS.semi16.copyWith(
                      color: Colors.white.withValues(
                        alpha: onChanged == null ? 0.38 : 1,
                      ),
                    ),
                  ),
                ),
                Switch(
                  value: value,
                  activeThumbColor: context.colorScheme.primary,
                  activeTrackColor: Colors.white,
                  inactiveThumbColor: Colors.white,
                  inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                  materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  onChanged: onChanged,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
