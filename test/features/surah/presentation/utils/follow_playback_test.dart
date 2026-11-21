import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/utils/follow_playback.dart';

void main() {
  group('nextFollowAction', () {
    test('no playing page returns null', () {
      expect(
        nextFollowAction(
          followPlayback: true,
          currentPage: 50,
          playingPage: null,
        ),
        isNull,
      );
    });

    test('already on the playing page returns null', () {
      expect(
        nextFollowAction(
          followPlayback: true,
          currentPage: 50,
          playingPage: 50,
        ),
        isNull,
      );
    });

    test('following on another page returns the playing page', () {
      expect(
        nextFollowAction(
          followPlayback: true,
          currentPage: 50,
          playingPage: 51,
        ),
        51,
      );
    });

    test('not following returns null', () {
      expect(
        nextFollowAction(
          followPlayback: false,
          currentPage: 50,
          playingPage: 51,
        ),
        isNull,
      );
    });
  });

  group('followAfterManualTurn', () {
    test('no playing page leaves follow true', () {
      expect(
        followAfterManualTurn(
          followPlayback: true,
          newPage: 9,
          playingPage: null,
        ),
        isTrue,
      );
    });

    test('no playing page leaves follow false', () {
      expect(
        followAfterManualTurn(
          followPlayback: false,
          newPage: 9,
          playingPage: null,
        ),
        isFalse,
      );
    });

    test('turning away by hand while following drops follow', () {
      expect(
        followAfterManualTurn(
          followPlayback: true,
          newPage: 51,
          playingPage: 50,
        ),
        isFalse,
      );
    });

    test('turning elsewhere while not following stays false', () {
      expect(
        followAfterManualTurn(
          followPlayback: false,
          newPage: 49,
          playingPage: 50,
        ),
        isFalse,
      );
    });

    test('landing by hand on the playing page re-arms follow', () {
      expect(
        followAfterManualTurn(
          followPlayback: false,
          newPage: 50,
          playingPage: 50,
        ),
        isTrue,
      );
    });

    test('staying on the playing page keeps follow', () {
      expect(
        followAfterManualTurn(
          followPlayback: true,
          newPage: 50,
          playingPage: 50,
        ),
        isTrue,
      );
    });
  });
}
