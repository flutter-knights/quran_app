import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import 'reel_request.dart';
import 'share_card_content.dart';

const reelMaxAyat = 10;
const reelMaxDuration = Duration(seconds: 60);

class ReelSegment extends Equatable {
  const ReelSegment({required this.content, required this.audio});

  final ShareCardContent content;
  final List<ReelAudio> audio;

  AyahIdentifier get ayah => content.ayah;

  Duration get duration =>
      audio.fold(Duration.zero, (sum, track) => sum + track.duration);

  @override
  List<Object> get props => [content, audio];
}
