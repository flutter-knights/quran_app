import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';

class CurrentAyahNotifier extends ValueNotifier<AyahIdentifier?> {
  CurrentAyahNotifier({required PlaybackCubit playbackCubit}) : super(null) {
    _sub = playbackCubit.stream
        .map((s) => s.currentAyah)
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
