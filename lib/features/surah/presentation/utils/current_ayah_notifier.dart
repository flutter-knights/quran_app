import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';

class CurrentAyahNotifier extends ValueNotifier<AyahIdentifier?> {
  CurrentAyahNotifier({required PlaybackCubit playbackCubit}) : super(null) {
    // During basmala the cubit keeps `currentAyah` pointed at the target verse
    // (so the overlay reports the right ayah for play/pause). But on the page
    // we want the basmala header line highlighted instead — bounds JSON files
    // index that line as `(surah, ayah: 0)` for every surah other than 1 and
    // 9. Translate here so MushafCubit.playingAyah picks up the basmala bound
    // and the painter lights it up.
    _sub = playbackCubit.stream
        .map((s) {
          final ayah = s.currentAyah;
          if (s.isPlayingBasmala && ayah != null) {
            return AyahIdentifier(surah: ayah.surah, ayah: 0);
          }
          return ayah;
        })
        .distinct((a, b) => a?.surah == b?.surah && a?.ayah == b?.ayah)
        .listen((ayah) => value = ayah);
  }

  late final StreamSubscription<AyahIdentifier?> _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
