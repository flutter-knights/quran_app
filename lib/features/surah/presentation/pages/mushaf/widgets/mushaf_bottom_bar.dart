import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/app_palette.dart';
import 'package:quran_app/core/constants/mushaf_paper.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_page_number_text.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';

class MushafBottomBar extends StatelessWidget {
  const MushafBottomBar({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: 46,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border(
            top: BorderSide(
              color: scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          children: [
            _PaperSwatches(),
            Expanded(child: _PageNumber()),
            _PlayFab(),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Paper swatches row
// ---------------------------------------------------------------------------

class _PaperSwatches extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SettingsCubit, SettingsState>(
      builder: (context, settingsState) {
        final scheme = Theme.of(context).colorScheme;
        final palette = settingsState.settingsModel.palette;
        final current = settingsState.settingsModel.mushafPaper;

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: MushafPaper.values.map((p) {
            final bgColor =
                p.colors(scheme, mushafBg: palette.mushafBg).background;
            final isActive = p == current;

            return Tooltip(
              message: p.label,
              child: GestureDetector(
                key: ValueKey('mushaf-paper-${p.name}'),
                onTap: () =>
                    context.read<SettingsCubit>().updateMushafPaper(p),
                child: Container(
                  width: 22,
                  height: 22,
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: bgColor,
                    border: isActive
                        ? Border.all(
                            color: scheme.primary,
                            width: 2,
                          )
                        : Border.all(
                            color: scheme.onSurface.withValues(alpha: 0.18),
                            width: 1,
                          ),
                  ),
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Page number (center)
// ---------------------------------------------------------------------------

class _PageNumber extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MushafCubit, MushafState>(
      buildWhen: (prev, next) => prev.currentPage != next.currentPage,
      builder: (context, state) {
        return Center(
          child: MushafPageNumberText(pageNumber: state.currentPage),
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Play FAB (end)
// ---------------------------------------------------------------------------

class _PlayFab extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return SizedBox(
      width: 34,
      height: 34,
      child: FilledButton(
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: Colors.white,
          padding: EdgeInsets.zero,
          minimumSize: const Size(34, 34),
          shape: const CircleBorder(),
        ),
        onPressed: () => _onPlay(context),
        child: const Icon(Icons.play_arrow, size: 18),
      ),
    );
  }

  void _onPlay(BuildContext context) {
    final mushafCubit = context.read<MushafCubit>();
    var firstAyah =
        sl<QuranPageService>().getFirstAyahOfPage(mushafCubit.state.currentPage);
    if (firstAyah != null) {
      if (firstAyah.ayah == 1 &&
          firstAyah.surah != 1 &&
          firstAyah.surah != 9) {
        firstAyah = AyahIdentifier(surah: firstAyah.surah, ayah: 0);
      }
      mushafCubit.toggleHighlight(firstAyah);
    } else {
      mushafCubit.pinOverlay();
    }
  }
}
