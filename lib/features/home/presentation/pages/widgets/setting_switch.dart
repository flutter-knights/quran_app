import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';
import 'package:quran_app/core/widgets/toggle_widget.dart';
import 'package:quran_app/features/settings/data/models/settings_model.dart';

class SettingSwitch extends StatelessWidget {
  const SettingSwitch({
    super.key,
    required this.settings,
    required this.settingTitle,
    required this.icons,
    required this.action,
    required this.value,
  });
  final SettingsModel settings;
  final bool value;
  final String settingTitle;
  final List<List<List<dynamic>>> icons;
  final VoidCallback action;

  @override
  Widget build(BuildContext context) {
    return PrettierTap(
      onTap: action,
      child: Row(
        mainAxisAlignment: .spaceBetween,
        children: [
          Row(
            spacing: 8,
            children: [
              SizedBox(
                height: 30,
                width: 30,
                child: ToggleWidget(
                  defaultChild: HugeIcon(icon: icons[0]),
                  targetChild: HugeIcon(icon: icons[1]),
                  value: value,
                ),
              ),

              Text(settingTitle, style: TS.bold20.cairo),
            ],
          ),

          Switch(value: value, onChanged: (_) => action()),
        ],
      ),
    );
  }
}
