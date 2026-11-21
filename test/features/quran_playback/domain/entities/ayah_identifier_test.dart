import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

void main() {
  test('realAyah folds the basmala header into ayah 1', () {
    expect(const AyahIdentifier(surah: 2, ayah: 0).realAyah, 1);
    expect(const AyahIdentifier(surah: 2, ayah: 7).realAyah, 7);
  });
}
