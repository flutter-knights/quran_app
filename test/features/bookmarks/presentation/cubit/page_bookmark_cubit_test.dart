import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/get_page_bookmarks.dart';
import 'package:quran_app/features/bookmarks/domain/usecases/toggle_page_bookmark.dart';
import 'package:quran_app/features/bookmarks/presentation/cubit/page_bookmark_cubit.dart';

class _MockGet extends Mock implements GetPageBookmarks {}
class _MockToggle extends Mock implements TogglePageBookmark {}

void main() {
  late _MockGet get;
  late _MockToggle toggle;

  setUp(() {
    get = _MockGet();
    toggle = _MockToggle();
  });

  test('loads existing bookmarks on creation', () async {
    when(() => get.call()).thenAnswer((_) async => const Right({3, 9}));
    final cubit = PageBookmarkCubit(getPageBookmarks: get, togglePageBookmark: toggle);
    await Future<void>.delayed(Duration.zero);
    expect(cubit.state.loaded, true);
    expect(cubit.state.pages, {3, 9});
    await cubit.close();
  });

  test('toggle adds a page to the set', () async {
    when(() => get.call()).thenAnswer((_) async => const Right(<int>{}));
    when(() => toggle.call(42)).thenAnswer((_) async => const Right(true));
    final cubit = PageBookmarkCubit(getPageBookmarks: get, togglePageBookmark: toggle);
    await Future<void>.delayed(Duration.zero);
    await cubit.toggle(42);
    expect(cubit.state.pages, {42});
    await cubit.close();
  });

  test('toggle removes a page when now unsaved', () async {
    when(() => get.call()).thenAnswer((_) async => const Right({42}));
    when(() => toggle.call(42)).thenAnswer((_) async => const Right(false));
    final cubit = PageBookmarkCubit(getPageBookmarks: get, togglePageBookmark: toggle);
    await Future<void>.delayed(Duration.zero);
    await cubit.toggle(42);
    expect(cubit.state.pages, <int>{});
    await cubit.close();
  });
}
