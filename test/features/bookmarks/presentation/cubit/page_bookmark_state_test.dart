import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_state.dart';

void main() {
  test('contains reflects the page set', () {
    const s = PageBookmarkState(pages: {3, 7}, loaded: true);
    expect(s.contains(3), true);
    expect(s.contains(4), false);
  });

  test('copyWith can clear error with explicit null', () {
    const s = PageBookmarkState(loaded: true, error: 'x');
    expect(s.copyWith(error: null).error, isNull);
    expect(s.copyWith(loaded: true).error, 'x'); // unspecified keeps old
  });
}
