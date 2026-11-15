import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/typography_styles.dart';

class AlertsSwitchRow extends StatelessWidget {
  const AlertsSwitchRow({
    super.key,
    required this.title,
    required this.value,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: SwitchListTile(
        contentPadding: const EdgeInsetsDirectional.symmetric(horizontal: 16),
        title: Text(title, style: TS.semi16),
        subtitle: subtitle == null
            ? null
            : Text(subtitle!, style: TS.regular14),
        value: value,
        onChanged: onChanged,
      ),
    );
  }
}
