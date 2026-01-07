import 'package:hive_flutter/hive_flutter.dart';

class QuranPlaybackLocalDataSource {
  final Box<String> audioBox;

  QuranPlaybackLocalDataSource({required this.audioBox});

  Future<void> cacheAudioMetadata(String url, String localPath) async {
    await audioBox.put(url, localPath);
  }

  String? getCachedLocalPath(String url) {
    return audioBox.get(url);
  }
}
