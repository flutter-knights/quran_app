import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/reading_settings_sheet.dart';

/// Glassy floating control dock shown when chrome is visible. Surah/juz/page
/// are printed on the page, so this is actions-only.
class MushafActionDock extends StatelessWidget {
  const MushafActionDock({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.55),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _DockButton(
                keyValue: 'dock-reading-settings',
                icon: Icons.tune,
                onTap: () => ReadingSettingsSheet.show(context),
              ),
              const SizedBox(width: 10),
              _DockButton(
                keyValue: 'dock-play',
                icon: Icons.play_arrow,
                primary: true,
                onTap: () => _onPlay(context),
              ),
              const SizedBox(width: 10),
              _DockButton(
                keyValue: 'dock-rotate',
                icon: MediaQuery.of(context).orientation == Orientation.portrait
                    ? Icons.stay_current_landscape
                    : Icons.stay_current_portrait,
                onTap: () => _onRotate(context),
              ),
              const SizedBox(width: 10),
              _DockButton(
                keyValue: 'dock-bookmark',
                icon: Icons.bookmark_outline,
                onTap: () {}, // existing bookmark flow wired in Phase 2
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onRotate(BuildContext context) {
    final isPortrait =
        MediaQuery.of(context).orientation == Orientation.portrait;
    SystemChrome.setPreferredOrientations(
      isPortrait
          ? [DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]
          : [DeviceOrientation.portraitUp, DeviceOrientation.portraitDown],
    );
  }

  void _onPlay(BuildContext context) {
    final mushafCubit = context.read<MushafCubit>();
    var firstAyah =
        sl<QuranPageService>().getFirstAyahOfPage(mushafCubit.state.currentPage);
    if (firstAyah != null) {
      if (firstAyah.ayah == 1 && firstAyah.surah != 1 && firstAyah.surah != 9) {
        firstAyah = AyahIdentifier(surah: firstAyah.surah, ayah: 0);
      }
      mushafCubit.toggleHighlight(firstAyah);
      final surah = firstAyah.surah;
      final start = firstAyah.ayah == 0
          ? AyahIdentifier(surah: surah, ayah: 1)
          : firstAyah;
      context.read<PlaybackCubit>().playRange(
            start: start,
            end: AyahIdentifier(surah: surah, ayah: quran.getVerseCount(surah)),
          );
    } else {
      mushafCubit.pinOverlay();
    }
    // Dismiss the dock so only the mini-player is visible.
    mushafCubit.setChrome(false);
  }
}

class _DockButton extends StatelessWidget {
  const _DockButton({
    required this.keyValue,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String keyValue;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final size = primary ? 46.0 : 36.0;
    return GestureDetector(
      key: ValueKey(keyValue),
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: primary ? scheme.primary : Colors.white.withValues(alpha: 0.12),
        ),
        child: Icon(icon,
            color: Colors.white, size: primary ? 24 : 20),
      ),
    );
  }
}
