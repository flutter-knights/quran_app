import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import 'reel_request.dart';
import 'share_card_content.dart';

const reelMaxAyat = 10;
const reelMaxDuration = Duration(seconds: 60);
const reelWidth = 1080.0;
const reelHeight = 1920.0;

class ReelSegment extends Equatable {
  const ReelSegment({required this.content, required this.audio, this.tafsir});

  final ShareCardContent content;
  final List<ReelAudio> audio;
  final String? tafsir;

  AyahIdentifier get ayah => content.ayah;

  Duration get duration =>
      audio.fold(Duration.zero, (sum, track) => sum + track.duration);

  ReelSegment withTafsir(String? tafsir) =>
      ReelSegment(content: content, audio: audio, tafsir: tafsir);

  @override
  List<Object?> get props => [content, audio, tafsir];
}
