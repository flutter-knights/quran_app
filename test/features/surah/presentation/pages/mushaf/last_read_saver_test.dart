import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/last_read_saver.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/mushaf_args.dart';

LastReadSaver _saver(
  List<LastRead> saved, {
  required MushafOrigin origin,
  LastRead Function()? readCurrent,
  DateTime Function()? now,
}) => LastReadSaver(
  readCurrent: readCurrent ?? () => const LastRead(page: 5),
  persist: (v) async => saved.add(v),
  origin: origin,
  now: now ?? DateTime.now,
);

void main() {
  test('schedule persists once after the debounce window', () {
    fakeAsync((async) {
      final saved = <LastRead>[];
      var page = 10;
      final saver = _saver(
        saved,
        origin: MushafOrigin.normal,
        readCurrent: () => LastRead(page: page),
      );

      saver.schedule();
      page = 11;
      saver.schedule();
      async.elapse(const Duration(milliseconds: 700));
      expect(saved, isEmpty);
      async.elapse(const Duration(milliseconds: 200));
      expect(saved.single.page, 11);
      expect(saved.single.updatedAt, isNotNull);
    });
  });

  test('flush persists immediately and cancels the pending timer', () {
    fakeAsync((async) {
      final saved = <LastRead>[];
      final saver = _saver(saved, origin: MushafOrigin.normal);
      saver.schedule();
      saver.flush();
      async.elapse(const Duration(seconds: 2));
      expect(saved.length, 1);
      expect(saved.single.page, 5);
    });
  });

  test('dispose cancels a pending timer, no save fires after dispose', () {
    fakeAsync((async) {
      final saved = <LastRead>[];
      final saver = _saver(saved, origin: MushafOrigin.normal);
      saver.schedule();
      saver.dispose();
      async.elapse(const Duration(seconds: 2));
      expect(saved, isEmpty);
    });
  });

  test('updatedAt comes from the injected clock', () {
    fakeAsync((async) {
      final saved = <LastRead>[];
      final stamp = DateTime(2026, 11, 21, 9, 40);
      final saver = _saver(
        saved,
        origin: MushafOrigin.normal,
        now: () => stamp,
      );
      saver.flush();
      expect(saved.single.updatedAt, stamp);
    });
  });

  test('normal: rearm guards again', () {
    fakeAsync((async) {
      final saved = <LastRead>[];
      final saver = _saver(saved, origin: MushafOrigin.normal);
      saver.rearm();
      saver.flush();
      expect(saved, isEmpty);
      async.elapse(const Duration(seconds: 20));
      expect(saved.length, 1);
    });
  });

  group('jump arrival', () {
    test('dispose-path flush does not write', () {
      fakeAsync((async) {
        final saved = <LastRead>[];
        final saver = _saver(saved, origin: MushafOrigin.jump);
        saver.flush();
        saver.dispose();
        async.elapse(const Duration(seconds: 30));
        expect(saved, isEmpty);
      });
    });

    test('pause-path flush does not write and the dwell keeps running', () {
      fakeAsync((async) {
        final saved = <LastRead>[];
        final saver = _saver(saved, origin: MushafOrigin.jump);
        saver.flush();
        async.elapse(const Duration(seconds: 1));
        expect(saved, isEmpty);
        async.elapse(const Duration(seconds: 19));
        expect(saved.length, 1);
      });
    });

    test('schedule does not write, even after the debounce', () {
      fakeAsync((async) {
        final saved = <LastRead>[];
        final saver = _saver(saved, origin: MushafOrigin.jump);
        saver.schedule();
        async.elapse(const Duration(seconds: 1));
        expect(saved, isEmpty);
      });
    });

    test('20 s dwell writes once with updatedAt from the clock', () {
      fakeAsync((async) {
        final saved = <LastRead>[];
        final stamp = DateTime(2026, 11, 21, 9, 40);
        _saver(saved, origin: MushafOrigin.jump, now: () => stamp);
        async.elapse(const Duration(seconds: 19));
        expect(saved, isEmpty);
        async.elapse(const Duration(seconds: 1));
        expect(saved.length, 1);
        expect(saved.single.updatedAt, stamp);
        async.elapse(const Duration(seconds: 40));
        expect(saved.length, 1);
      });
    });

    test('playback page change restarts the dwell', () {
      fakeAsync((async) {
        final saved = <LastRead>[];
        final saver = _saver(saved, origin: MushafOrigin.jump);
        async.elapse(const Duration(seconds: 15));
        saver.schedule();
        async.elapse(const Duration(seconds: 5));
        expect(saved, isEmpty);
        async.elapse(const Duration(seconds: 15));
        expect(saved.length, 1);
      });
    });

    test('manual turn then schedule writes after the debounce', () {
      fakeAsync((async) {
        final saved = <LastRead>[];
        final saver = _saver(saved, origin: MushafOrigin.jump);
        async.elapse(const Duration(seconds: 5));
        saver.onManualTurn();
        saver.schedule();
        async.elapse(const Duration(milliseconds: 800));
        expect(saved.length, 1);
        async.elapse(const Duration(seconds: 30));
        expect(saved.length, 1);
      });
    });
  });
}
