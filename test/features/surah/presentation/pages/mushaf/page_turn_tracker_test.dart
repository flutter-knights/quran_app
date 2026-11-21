import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/surah/presentation/pages/mushaf/page_turn_tracker.dart';

void main() {
  test('with nothing begun every page is manual', () {
    expect(PageTurnTracker().isManual(5), isTrue);
  });

  test('the begun page is not manual and the next one is', () {
    final t = PageTurnTracker()..begin(51);
    expect(t.isManual(51), isFalse);
    expect(t.isManual(52), isTrue);
  });

  test('pages passed through on the way are not manual', () {
    final t = PageTurnTracker()..begin(60);
    expect(t.isManual(58), isFalse);
    expect(t.isManual(60), isFalse);
    expect(t.isManual(61), isTrue);
  });

  test('an interrupted animation ends and the next page is manual', () {
    final t = PageTurnTracker();
    t.end(t.begin(51));
    expect(t.isManual(50), isTrue);
  });

  test('a jump to the current page does not swallow the next turn', () {
    final t = PageTurnTracker();
    t.end(t.begin(5));
    expect(t.isManual(6), isTrue);
  });

  test('a superseded turn ending does not clear the newer target', () {
    final t = PageTurnTracker();
    final first = t.begin(51);
    t.begin(51);
    t.end(first);
    expect(t.isManual(51), isFalse);
  });

  test('the newest turn ending clears the target', () {
    final t = PageTurnTracker();
    t.begin(51);
    t.end(t.begin(51));
    expect(t.isManual(51), isTrue);
  });
}
