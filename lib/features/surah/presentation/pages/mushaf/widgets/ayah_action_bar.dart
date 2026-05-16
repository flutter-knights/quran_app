import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as quran;
import 'package:share_plus/share_plus.dart';

import '../../../../../bookmarks/presentation/cubit/bookmark_cubit.dart';
import '../../../../../bookmarks/presentation/cubit/bookmark_state.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../../../../generated/l10n.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';

class AyahActionBar extends StatelessWidget {
  const AyahActionBar({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MushafCubit, MushafState>(
      buildWhen: (a, b) => a.highlightedAyah != b.highlightedAyah,
      builder: (context, state) {
        final ayah = state.highlightedAyah;
        final visible = ayah != null;
        return IgnorePointer(
          key: const ValueKey('ayah_action_bar_ignore'),
          ignoring: !visible,
          child: AnimatedSlide(
            offset: visible ? Offset.zero : const Offset(0, 1),
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOutCubic,
            child: AnimatedOpacity(
              opacity: visible ? 1.0 : 0.0,
              duration: const Duration(milliseconds: 180),
              child: Material(
                elevation: 8,
                color: Theme.of(context).colorScheme.surface,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsetsDirectional.symmetric(
                        horizontal: 8, vertical: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _BarButton(
                          key: const ValueKey('ayah_bar_tafsir'),
                          icon: Icons.menu_book_outlined,
                          label: S.of(context).tafsir,
                          onTap: () => _comingSoon(context),
                        ),
                        _BarButton(
                          key: const ValueKey('ayah_bar_translation'),
                          icon: Icons.translate,
                          label: S.of(context).translation,
                          onTap: () => _comingSoon(context),
                        ),
                        _BarButton(
                          key: const ValueKey('ayah_bar_play'),
                          icon: Icons.play_arrow,
                          label: S.of(context).play,
                          prominent: true,
                          onTap: () => _onPlay(context, ayah),
                        ),
                        _BookmarkButton(ayah: ayah),
                        _BarButton(
                          key: const ValueKey('ayah_bar_share'),
                          icon: Icons.share,
                          label: S.of(context).share,
                          onTap: () => _onShare(context, ayah),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  void _onPlay(BuildContext context, AyahIdentifier? ayah) {
    if (ayah == null) return;
    context.read<PlaybackCubit>().playFromAyah(ayah);
    context.read<MushafCubit>().clearHighlight();
  }

  Future<void> _onShare(BuildContext context, AyahIdentifier? ayah) async {
    if (ayah == null) return;
    try {
      final text = quran.getVerse(ayah.surah, ayah.ayah);
      await Share.share('$text — ${ayah.surah}:${ayah.ayah}');
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(S.of(context).share_failed)),
      );
    }
  }

  void _comingSoon(BuildContext context) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(S.of(context).coming_soon)),
    );
  }
}

class _BarButton extends StatelessWidget {
  const _BarButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.prominent = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = prominent ? scheme.primary : scheme.onSurface;
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26, color: color),
            const SizedBox(height: 4),
            Text(label, style: TextStyle(fontSize: 11, color: color)),
          ],
        ),
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.ayah});
  final AyahIdentifier? ayah;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookmarkCubit, BookmarkState>(
      buildWhen: (a, b) {
        if (ayah == null) return false;
        return a.contains(ayah!) != b.contains(ayah!);
      },
      builder: (context, state) {
        final on = ayah != null && state.contains(ayah!);
        return _BarButton(
          key: const ValueKey('ayah_bar_bookmark'),
          icon: on ? Icons.bookmark : Icons.bookmark_border,
          label: S.of(context).bookmark,
          onTap: () => _onTap(context),
        );
      },
    );
  }

  Future<void> _onTap(BuildContext context) async {
    final a = ayah;
    if (a == null) return;
    final cubit = context.read<BookmarkCubit>();
    final wasOn = cubit.state.contains(a);
    await cubit.toggle(a);
    if (!context.mounted) return;
    final state = cubit.state;
    final message = state.error != null
        ? S.of(context).bookmark_save_failed
        : (wasOn ? S.of(context).bookmark_removed : S.of(context).bookmark_added);
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
