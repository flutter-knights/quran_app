import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quran_app/features/bookmarks/data/datasources/local/page_bookmark_local_data_source.dart';

void main() {
  late Box<List> box;
  late PageBookmarkLocalDataSource ds;

  setUp(() async {
    Hive.init('./.dart_tool/hive_test_page_bm');
    box = await Hive.openBox<List>('page_bookmarks_test');
    await box.clear();
    ds = PageBookmarkLocalDataSource(box: box);
  });

  tearDown(() async {
    await box.clear();
    await box.close();
  });

  test('starts empty', () {
    expect(ds.getAll(), <int>{});
  });

  test('toggle adds then removes a page', () async {
    expect(await ds.toggle(42), true);
    expect(ds.getAll(), {42});
    expect(await ds.toggle(42), false);
    expect(ds.getAll(), <int>{});
  });

  test('keeps multiple pages', () async {
    await ds.toggle(3);
    await ds.toggle(100);
    expect(ds.getAll(), {3, 100});
  });
}
