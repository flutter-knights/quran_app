import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/ayah_share/domain/entities/reel_request.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

ReelClip _clip(List<int> seconds) => ReelClip(
  frame: Uint8List(0),
  audio: [
    for (final s in seconds)
      ReelAudio(
        path: '/a$s.mp3',
        duration: Duration(seconds: s),
      ),
  ],
);

void main() {
  test('file names carry the ayah or the range', () {
    const first = AyahIdentifier(surah: 6, ayah: 31);
    expect(
      ReelRequest(
        first: first,
        clips: [
          _clip([1]),
        ],
      ).fileName,
      'ayah_6_31.mp4',
    );

    const start = AyahIdentifier(surah: 2, ayah: 255);
    expect(
      ReelRequest(
        first: start,
        clips: [
          _clip([1]),
          _clip([1]),
          _clip([1]),
        ],
      ).fileName,
      'ayah_2_255-257.mp4',
    );
  });

  test('a clip lasts as long as its audio files together', () {
    expect(_clip([6, 3]).duration, const Duration(seconds: 9));
  });
}
