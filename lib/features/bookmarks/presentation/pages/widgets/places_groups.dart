import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper functions/locale_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/core/widgets/design/app_section_header.dart';
import 'package:quran_app/core/widgets/design/app_status_badge.dart';
import 'package:quran_app/core/widgets/design/directional_icons.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/fasil_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/saved_ayat_cubit.dart';
import 'package:quran_app/features/bookmarks/presentation/pages/widgets/place_row_menu.dart';
import 'package:quran_app/features/bookmarks/presentation/pages/widgets/place_tap_target.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/place_labels.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/settings/presentation/cubit/settings_cubit.dart';
import 'package:quran_app/features/surah/presentation/cubit/last_read/last_read_cubit.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_paper_colors.dart';
import 'package:quran_app/generated/l10n.dart';

String Function(DateTime) _whenFor(
  BuildContext context,
  DateTime Function() now,
) {
  final use24h = context.select(
    (SettingsCubit c) => c.state.settingsModel.is24HourFormat,
  );
  final langCode = context.langCode;
  return (at) =>
      placeWhen(at, now: now(), localeCode: langCode, use24h: use24h);
}

class PlacesGroups extends StatelessWidget {
  const PlacesGroups({
    super.key,
    required this.onOpen,
    this.now = DateTime.now,
  });

  final void Function(int page, AyahIdentifier? focus) onOpen;
  final DateTime Function() now;

  @override
  Widget build(BuildContext context) {
    final hasLastRead = context.select((LastReadCubit c) => c.state != null);
    return Column(
      spacing: 16,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (hasLastRead) _ContinueCard(now: now, onOpen: onOpen),
        _FasilSection(now: now, onOpen: onOpen),
        _SavedSection(now: now, onOpen: onOpen),
      ],
    );
  }
}

class _FasilSection extends StatelessWidget {
  const _FasilSection({required this.now, required this.onOpen});

  final DateTime Function() now;
  final void Function(int page, AyahIdentifier? focus) onOpen;

  @override
  Widget build(BuildContext context) {
    final slots = context.select((FasilCubit c) => c.state.slots);
    final when = _whenFor(context, now);
    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(label: PendingS.of(context).fasil_title),
        for (final slot in FasilSlot.values)
          _FasilRow(slot: slot, place: slots[slot], when: when, onOpen: onOpen),
      ],
    );
  }
}

class _SavedSection extends StatelessWidget {
  const _SavedSection({required this.now, required this.onOpen});

  final DateTime Function() now;
  final void Function(int page, AyahIdentifier? focus) onOpen;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final saved = context.select((SavedAyatCubit c) => c.state.items);
    final when = _whenFor(context, now);
    return Column(
      spacing: 8,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        AppSectionHeader(
          label: s.places_savedAyat,
          trailing: AppStatusBadge(
            color: context.colorScheme.secondary,
            label: saved.length.toLocalized(context),
            showDot: false,
          ),
        ),
        if (saved.isEmpty)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12),
            child: Text(
              s.places_noSavedAyat,
              style: TS.regular14.copyWith(
                color: context.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
        for (final place in saved)
          _SavedRow(place: place, when: when, onOpen: onOpen),
      ],
    );
  }
}

class _ContinueCard extends StatelessWidget {
  const _ContinueCard({required this.now, required this.onOpen});

  final DateTime Function() now;
  final void Function(int page, AyahIdentifier? focus) onOpen;

  @override
  Widget build(BuildContext context) {
    final lastRead = context.select((LastReadCubit c) => c.state);
    if (lastRead == null) return const SizedBox.shrink();
    final when = _whenFor(context, now);
    final s = PendingS.of(context);
    final scheme = context.colorScheme;
    final page = lastRead.page.toLocalized(context);
    final ayah = lastRead.ayah;
    final updatedAt = lastRead.updatedAt;
    final muted = TS.medium14.copyWith(color: scheme.onSurfaceVariant);
    return SurfaceCard(
      key: const ValueKey('places-continue'),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
      radius: 12,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(s.places_continue, style: TS.bold14),
          const SizedBox(height: 4),
          Text(
            ayah == null
                ? s.places_page(page)
                : s.places_position(ayahPlace(context, ayah), page),
            style: TS.bold14.copyWith(color: scheme.secondary),
          ),
          if (updatedAt != null) Text(when(updatedAt), style: muted),
          Text(s.places_continueCaption, style: muted),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              style: placeTapTarget,
              onPressed: () => onOpen(lastRead.page, null),
              child: Text(s.player_resume, style: TS.bold14),
            ),
          ),
        ],
      ),
    );
  }
}

class _FasilRow extends StatelessWidget {
  const _FasilRow({
    required this.slot,
    required this.place,
    required this.when,
    required this.onOpen,
  });

  final FasilSlot slot;
  final Place? place;
  final String Function(DateTime) when;
  final void Function(int page, AyahIdentifier? focus) onOpen;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final scheme = context.colorScheme;
    final muted = TS.medium14.copyWith(color: scheme.onSurfaceVariant);
    final placed = place;
    return SurfaceCard(
      key: ValueKey('places-fasil-${slot.name}'),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      radius: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Container(
              width: 12,
              height: 24,
              decoration: BoxDecoration(
                color: fasilRibbon(
                  slot,
                  dark: scheme.brightness == Brightness.dark,
                ),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(fasilName(context, slot, placed), style: TS.bold14),
                  Text(
                    placed == null
                        ? s.fasil_notPlaced
                        : s.places_position(
                            ayahPlace(context, placed.ayah),
                            placed.page.toLocalized(context),
                          ),
                    style: muted,
                  ),
                  if (placed != null)
                    Text(s.fasil_movedAt(when(placed.updatedAt)), style: muted),
                  if (placed != null)
                    Wrap(
                      children: [
                        TextButton(
                          key: ValueKey('places-go-${slot.name}'),
                          style: placeTapTarget,
                          onPressed: () => onOpen(placed.page, placed.ayah),
                          child: Text(s.menu_go, style: TS.bold14),
                        ),
                        TextButton(
                          key: ValueKey('places-rename-${slot.name}'),
                          style: placeTapTarget,
                          onPressed: () => _rename(context, placed),
                          child: Text(s.places_rename, style: TS.bold14),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _rename(BuildContext context, Place placed) async {
    final fawasil = context.read<FasilCubit>();
    final initial = fasilName(context, slot, placed);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => _RenameDialog(initial: initial),
    );
    if (name == null) return;
    if (placed.name == null && name.trim() == initial) return;
    await fawasil.rename(slot, name);
  }
}

class _RenameDialog extends StatefulWidget {
  const _RenameDialog({required this.initial});

  final String initial;

  @override
  State<_RenameDialog> createState() => _RenameDialogState();
}

class _RenameDialogState extends State<_RenameDialog> {
  late final _controller = TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    return AlertDialog(
      title: Text(s.places_renameTitle, style: TS.bold16),
      content: TextField(
        controller: _controller,
        autofocus: true,
        style: TS.medium14,
        textInputAction: TextInputAction.done,
        onSubmitted: (value) => Navigator.pop(context, value),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text(s.places_cancel, style: TS.bold14),
        ),
        TextButton(
          onPressed: () => Navigator.pop(context, _controller.text),
          child: Text(s.display_done, style: TS.bold14),
        ),
      ],
    );
  }
}

class _SavedRow extends StatelessWidget {
  const _SavedRow({
    required this.place,
    required this.when,
    required this.onOpen,
  });

  final Place place;
  final String Function(DateTime) when;
  final void Function(int page, AyahIdentifier? focus) onOpen;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final scheme = context.colorScheme;
    final ayah = place.ayah;
    return SurfaceCard(
      key: ValueKey('places-saved-${ayah.surah}:${ayah.ayah}'),
      padding: const EdgeInsetsDirectional.only(start: 14, end: 8),
      radius: 12,
      onTap: () => onOpen(place.page, ayah),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 56),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ayahPlace(context, ayah), style: TS.bold14),
                  if (!place.migrated)
                    Text(
                      s.savedAyat_savedAt(when(place.createdAt)),
                      style: TS.medium14.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            PlaceRowMenu(onRemove: () => _remove(context)),
            HugeIcon(
              icon: forwardArrowIcon(context),
              color: scheme.onSurfaceVariant,
              size: 18,
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _remove(BuildContext context) async {
    final saved = context.read<SavedAyatCubit>();
    final messenger = ScaffoldMessenger.of(context);
    final ayah = place.ayah;
    final message = PendingS.current.savedAyat_removed(
      ayah.ayah.toLocalized(context),
      surahDisplayName(context, ayah.surah),
    );
    final undo = S.of(context).undo;
    await saved.remove(place);
    if (saved.state.contains(ayah)) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(message),
        action: SnackBarAction(
          label: undo,
          onPressed: () => saved.restore(place),
        ),
      ),
    );
  }
}
