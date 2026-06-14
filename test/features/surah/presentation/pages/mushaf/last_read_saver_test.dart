import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/domain/entities/last_read.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/last_read_saver.dart';

void main() {
  test('schedule persists once after the debounce window', () {
    fakeAsync((async) {
      final saved = <LastRead>[];
      var page = 10;
      final saver = LastReadSaver(
        readCurrent: () => LastRead(page: page),
        persist: (v) async => saved.add(v),
        debounce: const Duration(milliseconds: 800),
      );

      saver.schedule();
      page = 11;
      saver.schedule(); // resets the timer
      async.elapse(const Duration(milliseconds: 700));
      expect(saved, isEmpty); // not yet
      async.elapse(const Duration(milliseconds: 200));
      expect(saved.single.page, 11); // once, with the latest page
    });
  });

  test('flush persists immediately and cancels the pending timer', () {
    fakeAsync((async) {
      final saved = <LastRead>[];
      final saver = LastReadSaver(
        readCurrent: () => const LastRead(page: 5),
        persist: (v) async => saved.add(v),
      );
      saver.schedule();
      saver.flush(); // immediate
      async.elapse(const Duration(seconds: 2));
      expect(saved.length, 1); // timer did not also fire
      expect(saved.single.page, 5);
    });
  });

  test('dispose cancels a pending timer — no save fires after dispose', () {
    fakeAsync((async) {
      final saved = <LastRead>[];
      final saver = LastReadSaver(
        readCurrent: () => const LastRead(page: 3),
        persist: (v) async => saved.add(v),
      );
      saver.schedule();
      saver.dispose(); // cancel before the debounce window elapses
      async.elapse(const Duration(seconds: 2));
      expect(saved, isEmpty);
    });
  });
}
