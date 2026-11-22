import 'package:dio/dio.dart';

import '../../models/tafsir_model.dart';

abstract class TafsirRemoteDataSource {
  Future<List<TafsirModel>> getPage(int page, {CancelToken? cancelToken});

  Future<TafsirModel> getAyah(int surah, int ayah, {CancelToken? cancelToken});
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
  Future<List<TafsirModel>> getPage(
    int page, {
    CancelToken? cancelToken,
  }) async {
    final data = await _get('$_base/page/$page/ar.muyassar', cancelToken);
    final ayahs = data['ayahs'];
    if (ayahs is! List) throw const FormatException('Missing ayahs');
    return [
      for (final item in ayahs)
        TafsirModel.fromJson(
          item is Map
              ? item
              : throw const FormatException('Malformed tafsir ayah'),
        ),
    ];
  }

  @override
  Future<TafsirModel> getAyah(
    int surah,
    int ayah, {
    CancelToken? cancelToken,
  }) async => TafsirModel.fromJson(
    await _get('$_base/ayah/$surah:$ayah/ar.muyassar', cancelToken),
  );

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
}
