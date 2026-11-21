import 'package:audio_service/audio_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:quran_app/features/quran_playback/presentation/audio/playback_state_mapper.dart';

void main() {
  test('maps just_audio ProcessingState to AudioProcessingState', () {
    expect(mapProcessingState(ProcessingState.idle), AudioProcessingState.idle);
    expect(
      mapProcessingState(ProcessingState.loading),
      AudioProcessingState.loading,
    );
    expect(
      mapProcessingState(ProcessingState.buffering),
      AudioProcessingState.buffering,
    );
    expect(
      mapProcessingState(ProcessingState.ready),
      AudioProcessingState.ready,
    );
    expect(
      mapProcessingState(ProcessingState.completed),
      AudioProcessingState.completed,
    );
  });
}
