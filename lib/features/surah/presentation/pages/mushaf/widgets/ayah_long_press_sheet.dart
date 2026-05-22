import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart' as quran;
import 'package:share_plus/share_plus.dart';

import '../../../../../../generated/l10n.dart';
import '../../../../../bookmarks/presentation/cubit/bookmark_cubit.dart';
import '../../../../../bookmarks/presentation/cubit/bookmark_state.dart';
import '../../../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../../../quran_playback/domain/entities/reciter.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../../../quran_playback/presentation/cubit/playback/playback_state.dart';

class AyahLongPressSheet extends StatelessWidget {
  const AyahLongPressSheet({super.key, required this.ayah});
  final AyahIdentifier ayah;

  static Future<void> show(BuildContext context, AyahIdentifier ayah) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => MultiBlocProvider(
        providers: [
          BlocProvider<PlaybackCubit>.value(value: context.read<PlaybackCubit>()),
          BlocProvider<BookmarkCubit>.value(value: context.read<BookmarkCubit>()),
        ],
        child: AyahLongPressSheet(ayah: ayah),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Text(
              s.ayah_label(ayah.surah.toString(), ayah.ayah.toString()),
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _ActionButton(
                  icon: Icons.menu_book_outlined,
                  label: s.tafsir,
                  onTap: () => _comingSoon(context),
                ),
                _ActionButton(
                  icon: Icons.translate,
                  label: s.translation,
                  onTap: () => _comingSoon(context),
                ),
                _BookmarkButton(ayah: ayah),
                _ActionButton(
                  icon: Icons.share,
                  label: s.share,
                  onTap: () => _onShare(context),
                ),
              ],
            ),
            const SizedBox(height: 20),
            Text(s.reciter_label, style: Theme.of(context).textTheme.labelLarge),
            const SizedBox(height: 8),
            BlocBuilder<PlaybackCubit, PlaybackState>(
              buildWhen: (a, b) => a.reciter != b.reciter,
              builder: (context, state) => DropdownButtonFormField<Reciter>(
                initialValue: state.reciter,
                isExpanded: true,
                decoration: InputDecoration(
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                items: [
                  for (final r in Reciter.values)
                    DropdownMenuItem<Reciter>(
                      value: r,
                      child: Text(r.arabicName),
                    ),
                ],
                onChanged: (r) {
                  if (r == null) return;
                  context.read<PlaybackCubit>().setReciter(r);
                  Navigator.of(context).pop();
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onShare(BuildContext context) async {
    try {
      final text = quran.getVerse(ayah.surah, ayah.ayah);
      Navigator.of(context).pop();
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

class _ActionButton extends StatelessWidget {
  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkResponse(
      onTap: onTap,
      radius: 28,
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 26),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11)),
          ],
        ),
      ),
    );
  }
}

class _BookmarkButton extends StatelessWidget {
  const _BookmarkButton({required this.ayah});
  final AyahIdentifier ayah;

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BookmarkCubit, BookmarkState>(
      buildWhen: (a, b) => a.contains(ayah) != b.contains(ayah),
      builder: (context, state) {
        final on = state.contains(ayah);
        return _ActionButton(
          icon: on ? Icons.bookmark : Icons.bookmark_border,
          label: S.of(context).bookmark,
          onTap: () => context.read<BookmarkCubit>().toggle(ayah),
        );
      },
    );
  }
}
