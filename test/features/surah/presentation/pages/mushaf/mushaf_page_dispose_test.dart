import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/constants/mushaf_reading_mode.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/quran_playback/presentation/cubit/playback/playback_state.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/presentation/cubit/mushaf/mushaf_state.dart';
import 'package:quran_app/features/surah/presentation/utils/mushaf_args.dart';

import 'mushaf_page_harness.dart';

void main() {
  setUp(setUpMushafHarness);

  Future<(StubLastReadRepo, FakePlayback)> disposeOn(
    WidgetTester tester,
    MushafArgs args, {
    Future<void> Function(FakeMushaf mushaf)? act,
    MushafState? mushafState,
    PlaybackState playbackState = const PlaybackState(),
    LastRead? stored,
    MushafReadingMode mode = MushafReadingMode.page,
  }) async {
    final mushaf = FakeMushaf(
      mushafState ??
          const MushafState(
            currentPage: 7,
            selectedAyah: AyahIdentifier(surah: 2, ayah: 5),
          ),
    );
    addTearDown(mushaf.close);
    final playback = FakePlayback(playbackState);
    final h = await pumpMushafPage(
      tester,
      args,
      mushaf: mushaf,
      playback: playback,
      settings: FakeSettings(mode: mode),
      stored: stored,
    );
    await act?.call(mushaf);
    await tester.pumpWidget(const MaterialApp(home: SizedBox.shrink()));
    await tester.pump();
    return (h.repo, playback);
  }

  testWidgets(
    'on dispose: saves (page, selected) and the recitation keeps playing',
    (tester) async {
      final (repo, playback) = await disposeOn(
        tester,
        const MushafArgs(page: 7),
        playbackState: const PlaybackState(
          currentAyah: AyahIdentifier(surah: 2, ayah: 5),
          isPlaying: true,
        ),
      );

      final saved = repo.saved!;
      expect(saved.page, 7);
      expect(saved.ayah, const AyahIdentifier(surah: 2, ayah: 5));
      expect(saved.updatedAt, isNotNull);
      expect(playback.stopCalls, 0);
      expect(
        playback.state.currentAyah,
        const AyahIdentifier(surah: 2, ayah: 5),
      );
    },
  );

  testWidgets('jump arrival: dispose does not overwrite last read', (
    tester,
  ) async {
    final (repo, playback) = await disposeOn(
      tester,
      const MushafArgs(page: 7, origin: MushafOrigin.jump),
    );

    expect(repo.saved, isNull);
    expect(playback.stopCalls, 0);
  });

  testWidgets('jump arrival: a manual page swipe lifts the guard', (
    tester,
  ) async {
    final (repo, _) = await disposeOn(
      tester,
      const MushafArgs(page: 7, origin: MushafOrigin.jump),
      act: (_) async {
        await tester.pumpAndSettle();
        await tester.drag(find.byType(PageView), const Offset(-400, 0));
        await tester.pumpAndSettle();
      },
    );

    expect(repo.saved, isNotNull);
  });

  testWidgets('in-place jump: dispose does not overwrite last read', (
    tester,
  ) async {
    final (repo, _) = await disposeOn(
      tester,
      const MushafArgs(page: 7),
      act: (_) async {
        await tester.tap(find.byKey(const ValueKey('foot-menu')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('menu-search')),
          '300',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('menu-go')));
        await tester.pumpAndSettle();
      },
    );

    expect(repo.saved, isNull);
  });

  testWidgets('a normal arrival on the last-read page keeps its ayah', (
    tester,
  ) async {
    const stored = LastRead(page: 7, ayah: AyahIdentifier(surah: 3, ayah: 5));
    final (repo, _) = await disposeOn(
      tester,
      const MushafArgs(page: 7),
      mushafState: const MushafState(currentPage: 7),
      stored: stored,
      act: (_) => tester.pumpAndSettle(),
    );

    expect(repo.saved!.page, 7);
    expect(repo.saved!.ayah, stored.ayah);
  });

  testWidgets('a stored ayah from another page is not carried over', (
    tester,
  ) async {
    final (repo, _) = await disposeOn(
      tester,
      const MushafArgs(page: 7),
      mushafState: const MushafState(currentPage: 7),
      stored: const LastRead(page: 50, ayah: AyahIdentifier(surah: 3, ayah: 5)),
      act: (_) => tester.pumpAndSettle(),
    );

    expect(repo.saved!.page, 7);
    expect(repo.saved!.ayah, isNull);
  });

  testWidgets('an in-place jump saves the pre-jump page, not the target', (
    tester,
  ) async {
    final (repo, _) = await disposeOn(
      tester,
      const MushafArgs(page: 7),
      mushafState: const MushafState(currentPage: 7),
      mode: MushafReadingMode.scroll,
      act: (mushaf) async {
        await tester.pumpAndSettle();
        mushaf.push(mushaf.state.copyWith(currentPage: 9));
        await tester.pump(const Duration(milliseconds: 100));
        await tester.tap(find.byKey(const ValueKey('foot-menu')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const ValueKey('menu-search')),
          '300',
        );
        await tester.pump();
        await tester.tap(find.byKey(const ValueKey('menu-go')));
        await tester.pumpAndSettle();
        expect(mushaf.state.currentPage, 300);
      },
    );

    expect(repo.saved!.page, 9);
  });
}
