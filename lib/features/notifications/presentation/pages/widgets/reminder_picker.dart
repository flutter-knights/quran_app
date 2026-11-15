import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/notifications/domain/entities/prayer_alert.dart';
import 'package:quran_app/features/notifications/presentation/utils/enum_localization.dart';

class ReminderPicker extends StatefulWidget {
  const ReminderPicker({
    super.key,
    required this.minutes,
    required this.enabled,
    required this.arrivesAt,
    required this.onCommit,
  });

  final int minutes;
  final bool enabled;
  final String? arrivesAt;
  final ValueChanged<int> onCommit;

  static const chipMinutes = [5, 10, 15, 30];

  @override
  State<ReminderPicker> createState() => _ReminderPickerState();
}

class _ReminderPickerState extends State<ReminderPicker> {
  late int _draft = widget.minutes;

  @override
  void didUpdateWidget(ReminderPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.minutes != widget.minutes) _draft = widget.minutes;
  }

  void _commit(int minutes) {
    setState(() => _draft = minutes);
    widget.onCommit(minutes);
  }

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final lang = context.langCode;
    final scheme = context.colorScheme;
    final enabled = widget.enabled;
    final mutedStyle = TS.regular12.copyWith(color: scheme.onSurfaceVariant);
    return Padding(
      padding: const EdgeInsetsDirectional.fromSTEB(16, 4, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              Text(
                s.alerts_sheet_reminderValue(minutesLabel(s, _draft, lang)),
                style: TS.semi20.copyWith(color: scheme.onSurface),
              ),
              if (widget.arrivesAt case final arrivesAt?)
                Text(
                  s.alerts_sheet_reminderArrives(arrivesAt),
                  style: TS.regular14.copyWith(color: scheme.onSurfaceVariant),
                ),
            ],
          ),
          Slider(
            value: _draft.toDouble(),
            min: PrayerAlert.minReminderMinutes.toDouble(),
            max: PrayerAlert.maxReminderMinutes.toDouble(),
            divisions:
                PrayerAlert.maxReminderMinutes - PrayerAlert.minReminderMinutes,
            onChanged: enabled
                ? (v) => setState(() => _draft = v.round())
                : null,
            onChangeEnd: enabled ? (v) => widget.onCommit(v.round()) : null,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                minutesLabel(s, PrayerAlert.minReminderMinutes, lang),
                style: mutedStyle,
              ),
              Text(
                minutesLabel(s, PrayerAlert.maxReminderMinutes, lang),
                style: mutedStyle,
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final m in ReminderPicker.chipMinutes)
                ChoiceChip(
                  label: Text(minutesLabel(s, m, lang)),
                  selected: _draft == m,
                  onSelected: enabled ? (_) => _commit(m) : null,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
