import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/tafsir/presentation/cubit/tafsir_cubit.dart';

import 'tafsir_fakes.dart';

void main() {
  const a = AyahIdentifier(surah: 1, ayah: 1);
  const none = AyahIdentifier(surah: 1, ayah: 0);

  test('ayah 0 records a cancel and keeps a loaded state', () async {
    final cubit = FakeTafsirCubit();
    await cubit.load(a);
    await cubit.load(none);
    expect(cubit.cancels, 1);
    expect(cubit.state, isA<TafsirLoaded>());
  });

  test('ayah 0 clears a loading state', () async {
    final cubit = FakeTafsirCubit(const TafsirLoading(a));
    await cubit.load(none);
    expect(cubit.cancels, 1);
    expect(cubit.state, const TafsirIdle());
  });
}
