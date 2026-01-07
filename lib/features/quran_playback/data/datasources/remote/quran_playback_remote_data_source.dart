import 'package:dio/dio.dart';

class QuranPlaybackRemoteDataSource {
  final Dio dio;

  QuranPlaybackRemoteDataSource({required this.dio});

  Future<String> downloadAudio(String url, String savePath) async {
    await dio.download(url, savePath);
    return savePath;
  }
}
