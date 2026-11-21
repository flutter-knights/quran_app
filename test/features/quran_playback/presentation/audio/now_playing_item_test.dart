import 'package:flutter_test/flutter_test.dart';
import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/domain/entities/reciter.dart';
import 'package:quran_app/features/quran_playback/presentation/audio/now_playing_item.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';

void main() {
  test('Arabic item names the surah, ayah, reciter and album, with no art', () {
    final item = nowPlayingItem(
      const PlaybackState(
        requestedAyah: AyahIdentifier(surah: 3, ayah: 4),
        reciter: Reciter.husary,
      ),
      langCode: 'ar',
    )!;
    expect(item.id, 'husary:3:4');
    expect(item.title, 'آل عمران، الآية ٤');
    expect(item.artist, 'محمود خليل الحصري');
    expect(item.album, 'القرآن الكريم');
    expect(item.artUri, isNull);
  });

  test('English item uses the English surah name and Latin digits', () {
    final item = nowPlayingItem(
      const PlaybackState(currentAyah: AyahIdentifier(surah: 3, ayah: 4)),
      langCode: 'en',
    )!;
    expect(item.title, '${quran.getSurahName(3)}, ayah 4');
    expect(item.album, 'The Holy Quran');
  });

  test('requestedAyah wins over currentAyah; idle gives null', () {
    expect(
      nowPlayingItem(
        const PlaybackState(
          currentAyah: AyahIdentifier(surah: 3, ayah: 4),
          requestedAyah: AyahIdentifier(surah: 3, ayah: 5),
        ),
        langCode: 'ar',
      )!.id,
      'alafasy:3:5',
    );
    expect(nowPlayingItem(const PlaybackState(), langCode: 'ar'), isNull);
  });
}
