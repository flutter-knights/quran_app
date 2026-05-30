import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/generated/l10n.dart';

/// Step 2 — language. Two large cards; tapping switches the locale live so the
/// rest of the wizard re-renders in the chosen language.
class LanguageStep extends StatelessWidget {
  const LanguageStep({super.key});

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final isArabic = context.select(
      (SettingsCubit c) => c.state.settingsModel.isArabic,
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 8),
          Text(
            s.onb_language_title,
            style: TS.bold20.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 4),
          Text(
            s.onb_language_hint,
            style: TS.regular12.copyWith(
              color: Colors.white.withValues(alpha: 0.65),
            ),
          ),
          const SizedBox(height: 16),
          _LangCard(
            label: s.language_arabic,
            sub: 'Arabic',
            selected: isArabic,
            onTap: () =>
                context.read<SettingsCubit>().updateSettings(isArabic: true),
          ),
          const SizedBox(height: 12),
          _LangCard(
            label: s.language_english,
            sub: 'الإنجليزية',
            selected: !isArabic,
            onTap: () =>
                context.read<SettingsCubit>().updateSettings(isArabic: false),
          ),
        ],
      ),
    );
  }
}

class _LangCard extends StatelessWidget {
  const _LangCard({
    required this.label,
    required this.sub,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final String sub;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final primary = Theme.of(context).colorScheme.primary;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: selected
              ? Colors.white
              : Colors.white.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? Colors.white
                : Colors.white.withValues(alpha: 0.16),
          ),
        ),
        child: Row(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TS.bold16.copyWith(
                    color: selected ? primary : Colors.white,
                  ),
                ),
                Text(
                  sub,
                  style: TS.regular12.copyWith(
                    color: (selected ? primary : Colors.white).withValues(
                      alpha: 0.6,
                    ),
                  ),
                ),
              ],
            ),
            const Spacer(),
            if (selected) Icon(Icons.check_circle_rounded, color: primary, size: 20),
          ],
        ),
      ),
    );
  }
}
