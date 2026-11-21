import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/quran_playback/presentation/audio/media_art.dart';

class _Bundle extends CachingAssetBundle {
  var loads = 0;

  @override
  Future<ByteData> load(String key) async {
    loads++;
    if (key != 'assets/icons/quran_icon.png') throw Exception('missing $key');
    return ByteData.sublistView(Uint8List.fromList([1, 2, 3]));
  }
}

void main() {
  late Directory dir;

  setUp(() => dir = Directory.systemTemp.createTempSync('media_art_test'));
  tearDown(() => dir.deleteSync(recursive: true));

  test('copies the bundled icon once and returns its file uri', () async {
    final bundle = _Bundle();
    final first = await mediaArtUri(dir: dir, bundle: bundle);
    final second = await mediaArtUri(dir: dir, bundle: bundle);
    expect(first, File('${dir.path}/media_art.png').uri);
    expect(second, first);
    expect(File.fromUri(first!).readAsBytesSync(), [1, 2, 3]);
    expect(bundle.loads, 1);
  });

  test('a missing asset gives no art', () async {
    final missing = Directory('${dir.path}/nope');
    expect(await mediaArtUri(dir: missing, bundle: _Bundle()), isNull);
  });
}
