import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/tafsir/data/datasources/remote/tafsir_remote_data_source.dart';
import 'package:quran_app/features/tafsir/domain/entities/tafsir.dart';

class _MockDio extends Mock implements Dio {}

Response<dynamic> _response(String url, Object? body) => Response(
  requestOptions: RequestOptions(path: url),
  statusCode: 200,
  data: body,
);

Map<String, Object?> _ayah(int surah, int ayah, String text) => {
  'number': surah * 1000 + ayah,
  'text': text,
  'surah': {'number': surah},
  'numberInSurah': ayah,
};

void main() {
  late _MockDio dio;
  late TafsirRemoteDataSourceImpl source;

  setUpAll(() {
    registerFallbackValue(CancelToken());
    registerFallbackValue(Options());
  });

  setUp(() {
    dio = _MockDio();
    source = TafsirRemoteDataSourceImpl(dio: dio);
  });

  void stub(String url, Object? body) {
    when(
      () => dio.get(
        url,
        cancelToken: any(named: 'cancelToken'),
        options: any(named: 'options'),
      ),
    ).thenAnswer((_) async => _response(url, body));
  }

  test('getPage reads every ayah of the page', () async {
    const url = 'https://api.alquran.cloud/v1/page/2/ar.muyassar';
    final token = CancelToken();
    stub(url, {
      'code': 200,
      'status': 'OK',
      'data': {
        'number': 2,
        'ayahs': [_ayah(2, 1, 'هذه الحروف'), _ayah(2, 2, 'ذلك الكتاب')],
      },
    });

    final items = await source.getPage(2, cancelToken: token);

    expect(items, const [
      Tafsir(surah: 2, ayah: 1, text: 'هذه الحروف'),
      Tafsir(surah: 2, ayah: 2, text: 'ذلك الكتاب'),
    ]);
    final captured =
        verify(
              () => dio.get(
                url,
                cancelToken: token,
                options: captureAny(named: 'options'),
              ),
            ).captured.single
            as Options;
    expect(captured.connectTimeout, const Duration(seconds: 10));
    expect(captured.receiveTimeout, const Duration(seconds: 15));
  });

  test('getAyah reads one ayah', () async {
    stub('https://api.alquran.cloud/v1/ayah/2:255/ar.muyassar', {
      'code': 200,
      'status': 'OK',
      'data': _ayah(2, 255, 'الله لا إله إلا هو'),
    });

    final item = await source.getAyah(2, 255);

    expect(item, const Tafsir(surah: 2, ayah: 255, text: 'الله لا إله إلا هو'));
  });

  test('a code other than 200 throws FormatException', () {
    stub('https://api.alquran.cloud/v1/page/9999/ar.muyassar', {
      'code': 404,
      'status': 'NOT FOUND',
      'data': 'Not found',
    });

    expect(source.getPage(9999), throwsA(isA<FormatException>()));
  });

  test('a string body throws FormatException', () {
    stub('https://api.alquran.cloud/v1/page/3/ar.muyassar', '<html>');

    expect(source.getPage(3), throwsA(isA<FormatException>()));
  });
}
