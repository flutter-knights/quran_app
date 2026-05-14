import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/di/dependency_injection.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_cubit.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/widgets/mushaf_text.dart';
import 'package:quran_app/features/surah/presentation/utils/current_ayah_notifier.dart';

class _FakePlaybackCubit extends Cubit<PlaybackState> implements PlaybackCubit {
  _FakePlaybackCubit() : super(const PlaybackState());
  @override
  // ignore: invalid_override_of_non_virtual_member
  dynamic noSuchMethod(Invocation i) => super.noSuchMethod(i);
}

void main() {
  late CurrentAyahNotifier notifier;

  setUp(() {
    notifier = CurrentAyahNotifier(playbackCubit: _FakePlaybackCubit());
    if (sl.isRegistered<CurrentAyahNotifier>()) {
      sl.unregister<CurrentAyahNotifier>();
    }
    sl.registerSingleton<CurrentAyahNotifier>(notifier);
  });

  tearDown(() async {
    if (sl.isRegistered<CurrentAyahNotifier>()) {
      sl.unregister<CurrentAyahNotifier>();
    }
    notifier.dispose();
  });

  testWidgets('renders RichText with the loaded spans', (tester) async {
    final loaded = MushafLoaded(
      page: MushafPageEntity(
        pageNumber: 2,
        ayahs: const ['ayah'],
        surahNames: const [],
        surahHeadersIndexes: const [],
        basmalaIndexes: const [],
        showBasmalaList: const [],
        ayahIdentifiers: const [AyahIdentifier(surah: 1, ayah: 1)],
      ),
      spans: const [TextSpan(text: 'ayah')],
      normalStyle: const TextStyle(),
      highlightedStyle: const TextStyle(),
      pageWidth: 300,
      fontSize: 14,
      lineHeight: 28,
    );
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: MushafText(loaded: loaded, pageNumber: 2)),
    ));
    expect(find.byType(RichText), findsWidgets);
    expect(find.byType(RepaintBoundary), findsWidgets);
  });
}
