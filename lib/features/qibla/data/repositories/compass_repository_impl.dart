import 'package:quran_app/features/qibla/data/datasources/compass_data_source.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_reading.dart';
import 'package:quran_app/features/qibla/domain/repositories/compass_repository.dart';

class CompassRepositoryImpl implements CompassRepository {
  CompassRepositoryImpl({required this.dataSource});

  final CompassDataSource dataSource;

  @override
  Stream<CompassReading> watchHeading() => dataSource.headingStream();
}
