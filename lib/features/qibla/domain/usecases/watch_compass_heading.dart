import 'package:quran_app/core/usecases/stream_usecase.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_reading.dart';
import 'package:quran_app/features/qibla/domain/repositories/compass_repository.dart';

class WatchCompassHeading extends StreamUseCase<CompassReading, NoParams> {
  WatchCompassHeading({required this.repository});

  final CompassRepository repository;

  @override
  Stream<CompassReading> call(NoParams params) => repository.watchHeading();
}
