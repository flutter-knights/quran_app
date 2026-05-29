import 'package:flutter/material.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_meta_service.dart';

const _arabicDigits = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

String _ar(int n) =>
    n.toString().split('').map((d) => _arabicDigits[int.parse(d)]).join();

class MushafTopBar extends StatelessWidget {
  const MushafTopBar({super.key, required this.pageNumber});

  final int pageNumber;

  @override
  Widget build(BuildContext context) {
    final meta = sl<QuranMetaService>().getPageMeta(pageNumber);
    final scheme = Theme.of(context).colorScheme;
    final name = quran.getSurahNameArabic(meta.surah);
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Container(
        height: 44,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        decoration: BoxDecoration(
          color: scheme.surface.withValues(alpha: 0.92),
          border: Border(
            bottom: BorderSide(
              color: scheme.onSurface.withValues(alpha: 0.08),
            ),
          ),
        ),
        child: Row(
          children: [
            Text(
              'الجزء ${_ar(meta.juz)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            Expanded(
              child: Text(
                name,
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ),
            Text(
              'حزب ${_ar(meta.hizb)} · ربع ${_ar(meta.rub)}',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
