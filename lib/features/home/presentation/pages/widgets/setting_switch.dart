import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
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
    return InkWell(
      borderRadius: BorderRadius.circular(12),
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
                child: HugeIcon(icon: icons[0], size: 28)
                    .animate(target: value ? 1 : 0)
                    .rotate(
                      duration: 300.ms,
                      begin: 0,
                      end: 0.2,
                      curve: Curves.ease,
                    )
                    .scale(
                      duration: 300.ms,
                      begin: const Offset(1, 1),
                      end: const Offset(0.8, 0.8),
                    )
                    .fade(duration: 300.ms, begin: 1, end: 0.2)
                    .swap(
                      delay: 300.ms,
                      duration: 0.ms,
                      builder: (_, _) => HugeIcon(icon: icons[1])
                          .animate()
                          .fade(duration: 300.ms, begin: 0.5, end: 1)
                          .scale(
                            duration: 300.ms,
                            begin: const Offset(0.8, 0.8),
                            end: const Offset(1, 1),
                          )
                          .rotate(
                            duration: 300.ms,
                            begin: -0.2,
                            end: 0,
                            curve: Curves.ease,
                          ),
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
