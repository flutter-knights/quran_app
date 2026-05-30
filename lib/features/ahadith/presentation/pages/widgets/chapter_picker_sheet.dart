import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/features/ahadith/domain/entities/chapter.dart';
import 'package:quran_app/generated/l10n.dart';

/// Small, searchable chapter picker shown as a bottom sheet over the filter
/// sheet. Returns the selected chapter id via [Navigator.pop], or `null` for
/// "All chapters". Returns nothing (dismissed) if the user swipes it away.
class ChapterPickerSheet extends StatefulWidget {
  const ChapterPickerSheet({
    super.key,
    required this.chapters,
    required this.selectedChapterId,
  });

  final List<Chapter> chapters;
  final int? selectedChapterId;

  /// Opens the picker. Resolves to a record with the chosen chapter id (which
  /// may be null for "All chapters"), or `null` when dismissed without picking.
  static Future<({int? chapterId})?> show(
    BuildContext context, {
    required List<Chapter> chapters,
    required int? selectedChapterId,
  }) {
    return showModalBottomSheet<({int? chapterId})>(
      context: context,
      backgroundColor: context.colorScheme.surface,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => ChapterPickerSheet(
        chapters: chapters,
        selectedChapterId: selectedChapterId,
      ),
    );
  }

  @override
  State<ChapterPickerSheet> createState() => _ChapterPickerSheetState();
}

class _ChapterPickerSheetState extends State<ChapterPickerSheet> {
  String _query = '';

  List<Chapter> get _filtered {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return widget.chapters;
    return widget.chapters.where((c) {
      return c.chapterNumber.toString().contains(q) ||
          c.chapterEnglish.toLowerCase().contains(q) ||
          c.chapterArabic.contains(_query.trim());
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    final filtered = _filtered;
    final sheetHeight = MediaQuery.of(context).size.height * 0.6;

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: SizedBox(
          height: sheetHeight,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: scheme.onSurface.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  S.of(context).filter_chapter_label,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  autofocus: false,
                  onChanged: (v) => setState(() => _query = v),
                  style: TextStyle(fontSize: 14, color: scheme.onSurface),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: S.of(context).filter_chapter_label,
                    prefixIcon: HugeIcon(
                      icon: HugeIcons.strokeRoundedSearch01,
                      size: 18,
                      color: scheme.onSurfaceVariant,
                    ),
                    prefixIconConstraints: const BoxConstraints(minWidth: 40),
                    filled: true,
                    fillColor: scheme.surfaceContainer,
                    contentPadding: const EdgeInsets.symmetric(vertical: 12),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: ListView(
                    children: [
                      _PickerRow(
                        label: S.of(context).filter_all_chapters,
                        selected: widget.selectedChapterId == null,
                        onTap: () =>
                            Navigator.of(context).pop((chapterId: null)),
                      ),
                      for (final c in filtered)
                        _PickerRow(
                          label:
                              '${c.chapterNumber}. ${isRtl ? c.chapterArabic : c.chapterEnglish}',
                          selected: widget.selectedChapterId == c.id,
                          onTap: () =>
                              Navigator.of(context).pop((chapterId: c.id)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _PickerRow extends StatelessWidget {
  const _PickerRow({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                  color: selected ? scheme.primary : scheme.onSurface,
                ),
              ),
            ),
            if (selected)
              Icon(Icons.check_rounded, size: 20, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}
