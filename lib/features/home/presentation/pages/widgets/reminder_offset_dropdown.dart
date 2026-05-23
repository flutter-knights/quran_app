import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/generated/l10n.dart';

/// Dropdown for picking a pre-prayer reminder offset.
///
/// Values: [0, 5, 10, 15] — 0 means "Off". When [enabled] is false the
/// dropdown is greyed and not interactive (its underlying value is preserved
/// in state, just visually muted).
class ReminderOffsetDropdown extends StatelessWidget {
  final int value;
  final bool enabled;
  final ValueChanged<int> onChanged;

  const ReminderOffsetDropdown({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  static const List<int> _values = [0, 5, 10, 15];

  String _labelFor(BuildContext context, int v) {
    if (v == 0) return S.of(context).reminderOff;
    return S.of(context).reminderMinutesBefore(v);
  }

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.4,
      child: DropdownButtonHideUnderline(
        child: DropdownButton<int>(
          value: value,
          isDense: true,
          icon: Icon(
            Icons.keyboard_arrow_down,
            color: context.colorScheme.onSurfaceVariant,
            size: 20,
          ),
          dropdownColor: context.colorScheme.surfaceContainerHigh,
          style: TS.regular14.cairo.copyWith(
            color: context.colorScheme.onSurface,
          ),
          onChanged: enabled ? (v) { if (v != null) onChanged(v); } : null,
          items: [
            for (final v in _values)
              DropdownMenuItem(value: v, child: Text(_labelFor(context, v))),
          ],
        ),
      ),
    );
  }
}
