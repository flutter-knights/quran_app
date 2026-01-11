import 'package:dio/dio.dart';

class QuranPlaybackRemoteDataSource {
  final Dio dio;

  QuranPlaybackRemoteDataSource({required this.dio});

  Future<String> downloadAudio(
    String url,
    String savePath, {
    int retries = 2,
  }) async {
    try {
      await dio.download(
        url,
        savePath,
        options: Options(
          receiveTimeout: const Duration(seconds: 15),
          sendTimeout: const Duration(seconds: 15),
        ),
      );

      return savePath;
    } catch (e) {
      if (retries > 0) {
        return downloadAudio(url, savePath, retries: retries - 1);
      }
      rethrow;
    }
  }
}
