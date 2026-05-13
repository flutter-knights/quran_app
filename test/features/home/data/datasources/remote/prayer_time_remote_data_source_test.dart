import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/home/data/datasources/remote/prayer_time_remote_data_source.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';

class _MockDio extends Mock implements Dio {}

void main() {
  late _MockDio dio;
  late PrayerTimeRemoteDataSource ds;

  setUp(() {
    dio = _MockDio();
    ds = PrayerTimeRemoteDataSource(dio: dio);
  });

  final location = Location(latitude: 30.0, longitude: 31.2);

  Response<dynamic> emptyResponse() => Response(
        data: {'data': <Map<String, dynamic>>[]},
        statusCode: 200,
        requestOptions: RequestOptions(path: ''),
      );

  test('without year/month: sends only lat/lng', () async {
    when(() => dio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => emptyResponse());

    await ds.getPrayerTimesList(location);

    final captured = verify(() => dio.get(
          'http://api.aladhan.com/v1/calendar',
          queryParameters: captureAny(named: 'queryParameters'),
        )).captured.single as Map<String, dynamic>;

    expect(captured['latitude'], 30.0);
    expect(captured['longitude'], 31.2);
    expect(captured.containsKey('month'), isFalse);
    expect(captured.containsKey('year'), isFalse);
  });

  test('with year/month: forwards them to the API', () async {
    when(() => dio.get(
          any(),
          queryParameters: any(named: 'queryParameters'),
        )).thenAnswer((_) async => emptyResponse());

    await ds.getPrayerTimesList(location, year: 2025, month: 6);

    final captured = verify(() => dio.get(
          'http://api.aladhan.com/v1/calendar',
          queryParameters: captureAny(named: 'queryParameters'),
        )).captured.single as Map<String, dynamic>;

    expect(captured['latitude'], 30.0);
    expect(captured['longitude'], 31.2);
    expect(captured['month'], 6);
    expect(captured['year'], 2025);
  });
}
