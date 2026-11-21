import 'package:audio_service/audio_service.dart' show MediaItem;
import 'package:quran/quran.dart' as quran;

import '../../../../core/helper functions/numeral_helpers.dart';
import '../../../../core/localization/pending_s.dart';
import '../cubit/playback/playback_state.dart';

MediaItem? nowPlayingItem(
  PlaybackState state, {
  required String langCode,
  Uri? artUri,
}) {
  final ayah = state.nowPlaying;
  if (ayah == null) return null;
  final strings = PendingS.forLanguage(langCode);
  final surahName = langCode == 'ar'
      ? quran.getSurahNameArabic(ayah.surah)
      : quran.getSurahName(ayah.surah);
  return MediaItem(
    id: '${state.reciter.name}:${ayah.surah}:${ayah.ayah}',
    title: strings.playback_mediaTitle(
      surahName,
      ayah.ayah.toString().toIndicNumerals(langCode),
    ),
    artist: state.reciter.arabicName,
    album: strings.playback_mediaAlbum,
    artUri: artUri,
  );
}
