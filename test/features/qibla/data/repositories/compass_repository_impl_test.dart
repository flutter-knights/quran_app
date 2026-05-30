import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:quran_app/features/qibla/data/datasources/compass_data_source.dart';
import 'package:quran_app/features/qibla/data/repositories/compass_repository_impl.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_reading.dart';

class _MockCompassDataSource extends Mock implements CompassDataSource {}

void main() {
  late _MockCompassDataSource ds;
  late CompassRepositoryImpl repo;

  setUp(() {
    ds = _MockCompassDataSource();
    repo = CompassRepositoryImpl(dataSource: ds);
  });

  test('forwards the data source stream', () {
    when(() => ds.headingStream()).thenAnswer(
      (_) => Stream.fromIterable(const [
        CompassReading(heading: 90, accuracy: 5),
        CompassReading(heading: 91, accuracy: 5),
      ]),
    );

    expect(
      repo.watchHeading(),
      emitsInOrder(const [
        CompassReading(heading: 90, accuracy: 5),
        CompassReading(heading: 91, accuracy: 5),
      ]),
    );
  });

  test('passes through a null-heading reading (no magnetometer)', () {
    when(() => ds.headingStream()).thenAnswer(
      (_) => Stream.value(const CompassReading(heading: null)),
    );

    expect(
      repo.watchHeading(),
      emits(const CompassReading(heading: null)),
    );
  });
}
