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
}
