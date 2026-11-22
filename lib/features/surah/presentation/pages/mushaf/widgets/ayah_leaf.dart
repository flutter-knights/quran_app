import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_status_badge.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_state.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/place_notices.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/features/surah/presentation/utils/surah_caption.dart';
import 'package:quran_app/features/tafsir/presentation/widgets/tafsir_section.dart';
import 'package:quran_app/generated/l10n.dart';

class AyahLeaf extends StatelessWidget {
  const AyahLeaf({
    super.key,
    required this.ayah,
    required this.colors,
    required this.onClose,
    required this.onListenFromHere,
    required this.onListenFromSurahStart,
    required this.onListenPage,
    required this.onFasil,
    required this.onExpand,
    required this.tafsirLead,
  });

  final AyahIdentifier ayah;
  final MushafPaperColors colors;
  final VoidCallback onClose;
  final VoidCallback onListenFromHere;
  final VoidCallback onListenFromSurahStart;
  final VoidCallback onListenPage;
  final VoidCallback onFasil;
  final VoidCallback onExpand;
  final bool tafsirLead;

  bool get _isBanner => ayah.ayah == 0;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final scheme = context.colorScheme;
    final strings = S.of(context);
    final name = surahDisplayName(context, ayah.surah);
    final title = _isBanner
        ? s.mushaf_surahTitle(name)
        : s.playback_mediaTitle(name, ayah.ayah.toLocalized(context));
    return GestureDetector(
      onVerticalDragEnd: (details) {
        final velocity = details.primaryVelocity ?? 0;
        if (velocity > 300) onClose();
        if (!_isBanner && velocity < -300) onExpand();
      },
      child: Material(
        color: colors.leaf,
        shape: Border(top: BorderSide(color: colors.accent)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 12,
            children: [
              Row(
                spacing: 8,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: TS.bold16.copyWith(color: colors.ink),
                        ),
                        if (_isBanner)
                          Text(
                            surahCaption(context, ayah.surah),
                            style: TS.medium14.copyWith(color: colors.ink2),
                          ),
                      ],
                    ),
                  ),
                  if (quran.isSajdahVerse(ayah.surah, ayah.ayah))
                    AppStatusBadge(
                      color: colors.accent,
                      label: s.leaf_sajda,
                      showDot: false,
                    ),
                  TextButton.icon(
                    key: const ValueKey('leaf-close'),
                    style: TextButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      foregroundColor: colors.ink,
                    ),
                    onPressed: onClose,
                    icon: const HugeIcon(
                      icon: HugeIcons.strokeRoundedCancel01,
                      size: 18,
                    ),
                    label: Text(strings.playback_close, style: TS.semi14),
                  ),
                ],
              ),
              if (_isBanner)
                Row(
                  spacing: 8,
                  children: [
                    Expanded(
                      child: FilledButton(
                        key: const ValueKey('leaf-surah-start'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(0, 48),
                        ),
                        onPressed: onListenFromSurahStart,
                        child: Text(
                          s.mushaf_playFromSurahStart,
                          textAlign: TextAlign.center,
                          style: TS.semi14,
                        ),
                      ),
                    ),
                    Expanded(
                      child: OutlinedButton(
                        key: const ValueKey('leaf-page'),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size(0, 48),
                          foregroundColor: colors.ink,
                          side: BorderSide(color: colors.accent),
                        ),
                        onPressed: onListenPage,
                        child: Text(
                          s.mushaf_playWholePage,
                          textAlign: TextAlign.center,
                          style: TS.semi14,
                        ),
                      ),
                    ),
                  ],
                )
              else ...[
                IntrinsicHeight(
                  child: Row(
                    children: [
                      Expanded(
                        child: _Action(
                          key: const ValueKey('leaf-listen'),
                          icon: HugeIcons.strokeRoundedPlay,
                          label: s.leaf_listenFromHere,
                          color: scheme.onPrimary,
                          fill: scheme.primary,
                          onTap: onListenFromHere,
                        ),
                      ),
                      VerticalDivider(width: 1, color: colors.accent),
                      Expanded(
                        child: _Action(
                          key: const ValueKey('leaf-tafsir'),
                          icon: HugeIcons.strokeRoundedBookOpen01,
                          label: s.leaf_tafsir,
                          color: colors.ink,
                          onTap: onExpand,
                        ),
                      ),
                      VerticalDivider(width: 1, color: colors.accent),
                      Expanded(
                        child: _Action(
                          key: const ValueKey('leaf-fasil'),
                          icon: HugeIcons.strokeRoundedBookmark03,
                          label: s.leaf_fasil,
                          color: colors.ink,
                          onTap: onFasil,
                        ),
                      ),
                      VerticalDivider(width: 1, color: colors.accent),
                      Expanded(
                        child:
                            BlocSelector<SavedAyatCubit, SavedAyatState, bool>(
                              selector: (state) => state.contains(ayah),
                              builder: (context, saved) => _Action(
                                key: const ValueKey('leaf-save'),
                                icon: saved
                                    ? HugeIcons.strokeRoundedBookmarkCheck02
                                    : HugeIcons.strokeRoundedBookmark02,
                                label: s.leaf_saveAyah,
                                color: colors.ink,
                                toggled: saved,
                                onTap: () => _toggleSave(context),
                              ),
                            ),
                      ),
                    ],
                  ),
                ),
                if (tafsirLead)
                  TafsirSection(
                    key: const ValueKey('tafsir-lead'),
                    ayah: ayah,
                    ink: colors.ink,
                    mutedInk: colors.ink2,
                    buttonStyle: colors.paperButton(),
                    lead: true,
                    onTap: onExpand,
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleSave(BuildContext context) async {
    final saved = context.read<SavedAyatCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final s = PendingS.current;
    final ayahText = ayah.ayah.toLocalized(context);
    final surahText = surahDisplayName(context, ayah.surah);
    final existing = saved.state.find(ayah);
    if (existing != null) {
      await saved.remove(existing);
      if (saved.state.contains(ayah)) return showPlaceWriteError(messenger);
      showPlaceNotice(
        messenger,
        s.savedAyat_removed(ayahText, surahText),
        onUndo: () => saved.restore(existing),
      );
      return;
    }
    final place = await saved.save(ayah);
    if (place == null) {
      if (saved.state.error != null) showPlaceWriteError(messenger);
      return;
    }
    showPlaceNotice(
      messenger,
      s.savedAyat_saved(ayahText, surahText),
      onUndo: () => saved.remove(place),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    super.key,
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.fill,
    this.toggled,
  });

  final List<List<dynamic>> icon;
  final String label;
  final Color color;
  final Color? fill;
  final bool? toggled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: toggled,
      container: true,
      child: Material(
        color: fill ?? Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 56),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                spacing: 4,
                children: [
                  HugeIcon(icon: icon, color: color, size: 22),
                  Text(
                    label,
                    textAlign: TextAlign.center,
                    style: TS.semi14.copyWith(color: color),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
