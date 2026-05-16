import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/quran_page_service.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/auto_swap_helper.dart';

class _MockPageService extends Mock implements QuranPageService {}

void main() {
  late _MockPageService service;

  setUp(() => service = _MockPageService());

  test('returns target index when playingAyah is on a different page', () {
    when(() => service.getPageForAyah(2, 255)).thenReturn(5);

    final result = computeAutoSwapTargetIndex(
      playingAyah: const AyahIdentifier(surah: 2, ayah: 255),
      currentPageIndex: 0,
      pageService: service,
    );

    expect(result, 4); // page 5 → index 4
  });

  test('returns null when playingAyah is on the current page', () {
    when(() => service.getPageForAyah(1, 1)).thenReturn(1);

    final result = computeAutoSwapTargetIndex(
      playingAyah: const AyahIdentifier(surah: 1, ayah: 1),
      currentPageIndex: 0,
      pageService: service,
    );

    expect(result, isNull);
  });

  test('returns null when playingAyah is null', () {
    final result = computeAutoSwapTargetIndex(
      playingAyah: null,
      currentPageIndex: 0,
      pageService: service,
    );

    expect(result, isNull);
    verifyNever(() => service.getPageForAyah(any(), any()));
  });

  test('returns null when currentPageIndex is null (controller detached)', () {
    when(() => service.getPageForAyah(2, 255)).thenReturn(5);

    final result = computeAutoSwapTargetIndex(
      playingAyah: const AyahIdentifier(surah: 2, ayah: 255),
      currentPageIndex: null,
      pageService: service,
    );

    expect(result, isNull);
  });
}
