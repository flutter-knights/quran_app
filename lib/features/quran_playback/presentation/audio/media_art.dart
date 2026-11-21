import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:quran_app/core/constants/assets_dir.dart';

Future<Uri?> mediaArtUri({required Directory dir, AssetBundle? bundle}) async {
  try {
    final file = File('${dir.path}/media_art.png');
    if (!file.existsSync()) {
      final data = await (bundle ?? rootBundle).load(
        AssetsDir.iconsDir('quran_icon.png'),
      );
      await file.writeAsBytes(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
        flush: true,
      );
    }
    return file.uri;
  } catch (e) {
    debugPrint('media art unavailable: $e');
    return null;
  }
}
