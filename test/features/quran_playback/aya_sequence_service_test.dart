import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/services/aya_sequence_service.dart';

void main() {
  final svc = AyahSequenceService();

  test('previous within same surah', () {
    final prev = svc.getPreviousAyah(
      current: const AyahIdentifier(surah: 2, ayah: 3),
    );
    expect(prev, const AyahIdentifier(surah: 2, ayah: 2));
  });

  test('previous at surah boundary wraps to last ayah of previous surah', () {
    final prev = svc.getPreviousAyah(
      current: const AyahIdentifier(surah: 2, ayah: 1),
    );
    // Al-Fatihah has 7 ayahs.
    expect(prev, const AyahIdentifier(surah: 1, ayah: 7));
  });

  test('previous from 1:1 returns null', () {
    final prev = svc.getPreviousAyah(
      current: const AyahIdentifier(surah: 1, ayah: 1),
    );
    expect(prev, isNull);
  });

  test('next stops past the range end', () {
    final next = svc.getNextAyah(
      current: const AyahIdentifier(surah: 2, ayah: 8),
      endSurah: 2,
      endAyah: 7,
    );
    expect(next, isNull);
  });

  test('next crosses surahs inside a cross-surah range', () {
    final next = svc.getNextAyah(
      current: const AyahIdentifier(surah: 4, ayah: 176),
      endSurah: 5,
      endAyah: 2,
    );
    expect(next, const AyahIdentifier(surah: 5, ayah: 1));
  });

  test('next at the end of the mushaf', () {
    final next = svc.getNextAyah(
      current: const AyahIdentifier(surah: 114, ayah: 6),
    );
    expect(next, isNull);
  });
}
