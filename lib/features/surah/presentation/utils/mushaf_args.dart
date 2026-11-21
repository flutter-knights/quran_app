import 'package:quran/quran.dart' as quran;
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

enum MushafOrigin { normal, jump }

class MushafArgs {
  final int page;
  final AyahIdentifier? focusAyah;
  final int? openedSurah;
  final MushafOrigin origin;

  const MushafArgs({
    required this.page,
    this.focusAyah,
    this.openedSurah,
    this.origin = MushafOrigin.normal,
  });

  factory MushafArgs.focus(AyahIdentifier ayah) => MushafArgs(
    page: quran.getPageNumber(ayah.surah, ayah.realAyah),
    focusAyah: ayah,
    openedSurah: ayah.surah,
    origin: MushafOrigin.jump,
  );

  factory MushafArgs.nowPlaying(AyahIdentifier ayah) => MushafArgs(
    page: quran.getPageNumber(ayah.surah, ayah.realAyah),
    openedSurah: ayah.surah,
    origin: MushafOrigin.jump,
  );
}
