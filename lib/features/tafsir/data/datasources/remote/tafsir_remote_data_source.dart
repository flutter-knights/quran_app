import 'package:dio/dio.dart';

import '../../../domain/entities/tafsir.dart';

abstract class TafsirRemoteDataSource {
  Future<List<Tafsir>> getPage(int page, {CancelToken? cancelToken});

  Future<Tafsir> getAyah(int surah, int ayah, {CancelToken? cancelToken});
}

class TafsirRemoteDataSourceImpl implements TafsirRemoteDataSource {
  TafsirRemoteDataSourceImpl({required this.dio});

  final Dio dio;

  static const _base = 'https://api.alquran.cloud/v1';
  static final _options = Options(
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
  );

  @override
  Future<List<Tafsir>> getPage(int page, {CancelToken? cancelToken}) async {
    final data = await _get('$_base/page/$page/ar.muyassar', cancelToken);
    final ayahs = data['ayahs'];
    if (ayahs is! List) throw const FormatException('Missing ayahs');
    return [
      for (final item in ayahs)
        if (item is Map) _parse(item),
    ];
  }

  @override
  Future<Tafsir> getAyah(
    int surah,
    int ayah, {
    CancelToken? cancelToken,
  }) async =>
      _parse(await _get('$_base/ayah/$surah:$ayah/ar.muyassar', cancelToken));

  Future<Map> _get(String url, CancelToken? cancelToken) async {
    final response = await dio.get(
      url,
      cancelToken: cancelToken,
      options: _options,
    );
    final body = response.data;
    if (body is Map && body['code'] == 200 && body['data'] is Map) {
      return body['data'] as Map;
    }
    throw const FormatException('Unexpected tafsir response');
  }

  Tafsir _parse(Map item) {
    final surah = item['surah'];
    final number = surah is Map ? surah['number'] : null;
    final ayah = item['numberInSurah'];
    final text = item['text'];
    if (number is! int || ayah is! int || text is! String) {
      throw const FormatException('Malformed tafsir ayah');
    }
    return Tafsir(surah: number, ayah: ayah, text: text);
  }
}
