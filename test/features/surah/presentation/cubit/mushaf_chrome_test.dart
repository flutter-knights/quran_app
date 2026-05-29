import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_cubit.dart';

void main() {
  test('toggleChrome flips chromeVisible; default false; setChrome sets it',
      () {
    final notifier = ValueNotifier<AyahIdentifier?>(null);
    final cubit = MushafCubit(
      initialPage: 1,
      currentAyahNotifier: notifier,
    );

    expect(cubit.state.chromeVisible, isFalse);

    cubit.toggleChrome();
    expect(cubit.state.chromeVisible, isTrue);

    cubit.setChrome(false);
    expect(cubit.state.chromeVisible, isFalse);

    cubit.close();
    notifier.dispose();
  });

  test('clearing chrome keeps the highlighted ayah', () {
    final notifier = ValueNotifier<AyahIdentifier?>(null);
    final cubit = MushafCubit(
      initialPage: 1,
      currentAyahNotifier: notifier,
    );

    const ayah = AyahIdentifier(surah: 2, ayah: 255);
    cubit.toggleHighlight(ayah);
    cubit.setChrome(false);

    expect(cubit.state.highlightedAyah, equals(ayah));
    expect(cubit.state.chromeVisible, isFalse);

    cubit.close();
    notifier.dispose();
  });
}
