import 'package:hive_ce_flutter/hive_flutter.dart';

class QuranPlaybackLocalDataSource {
  final Box<String> audioBox;
  final Box<bool> downloadsBox;

  QuranPlaybackLocalDataSource({
    required this.audioBox,
    required this.downloadsBox,
  });

  Future<void> cacheAudioMetadata(String url, String localPath) async {
    await audioBox.put(url, localPath);
  }

  String? getCachedLocalPath(String url) {
    return audioBox.get(url);
  }

  Future<void> removeCachedPath(String url) => audioBox.delete(url);

  bool isSurahDownloaded(String key) => downloadsBox.get(key) ?? false;

  Future<void> markSurahDownloaded(String key) => downloadsBox.put(key, true);

  Future<void> clearSurahDownloaded(String key) => downloadsBox.delete(key);
}
