import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/settings/presentation/pages/widgets/palette_picker_widget.dart';
import 'package:quran_app/generated/l10n.dart';

/// Step 3 — appearance. Theme reuses the settings [PalettePickerWidget] (tiles
/// painted in each palette's real colours = an in-app preview), plus a time
/// format toggle and the "show splash next launch" switch. Selections apply
/// live via [SettingsCubit].
class AppearanceStep extends StatelessWidget {
  const AppearanceStep({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final cubit = context.read<SettingsCubit>();
    final settings = context.watch<SettingsCubit>().state.settingsModel;

    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            s.onb_appearance_title,
            style: TS.bold20.copyWith(color: Colors.white),
          ),

          _Label(s.onb_theme_label),
          PalettePickerWidget(
            currentPalette: settings.palette,
            onSelect: cubit.updatePalette,
          ),

          _Label(s.onb_time_format_label),
          _TwoWayToggle(
            // Inverted flag: `false` selects 12-hour.
            leftSelected: !settings.isFormat12Hours,
            leftLabel: s.time_format_12h,
            rightLabel: s.time_format_24h,
            onLeft: () => cubit.updateSettings(isFormat12Hours: false),
            onRight: () => cubit.updateSettings(isFormat12Hours: true),
          ),

          _Label(s.show_splash_screen),
          Row(
            children: [
              Expanded(
                child: Text(
                  s.onb_splash_desc,
                  style: TS.regular12.copyWith(
                    color: Colors.white.withValues(alpha: 0.65),
                  ),
                ),
              ),
              Switch(
                value: settings.showSplashOnLaunch,
                activeThumbColor: Theme.of(context).colorScheme.primary,
                activeTrackColor: Colors.white,
                inactiveThumbColor: Colors.white,
                inactiveTrackColor: Colors.white.withValues(alpha: 0.2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                onChanged: cubit.updateShowSplashOnLaunch,
              ),
            ],
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(2, 18, 2, 10),
      child: Text(
        text,
        style: TS.bold12.copyWith(
          color: Colors.white.withValues(alpha: 0.6),
          letterSpacing: 1,
        ),
      ),
    );
  }
}

/// White-on-backdrop segmented pill (the themed selector wouldn't read on the
/// green splash backdrop).
class _TwoWayToggle extends StatelessWidget {
  const _TwoWayToggle({
    required this.leftSelected,
    required this.leftLabel,
    required this.rightLabel,
    required this.onLeft,
    required this.onRight,
  });

  final bool leftSelected;
  final String leftLabel;
  final String rightLabel;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(11),
        border: Border.all(color: Colors.white.withValues(alpha: 0.16)),
      ),
      padding: const EdgeInsets.all(3),
      child: Row(
        children: [
          _seg(leftLabel, leftSelected, onLeft, primary),
          _seg(rightLabel, !leftSelected, onRight, primary),
        ],
      ),
    );
  }

  Widget _seg(String label, bool selected, VoidCallback onTap, Color primary) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: BoxDecoration(
            color: selected ? Colors.white : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TS.semi12.copyWith(
              color: selected ? primary : Colors.white.withValues(alpha: 0.8),
            ),
          ),
        ),
      ),
    );
  }
}
