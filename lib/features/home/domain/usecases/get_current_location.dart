import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/stream_usecase.dart';
import 'package:quran_app/core/usecases/usecase.dart';

import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';

class GetCurrentLocationUseCase
    extends StreamUseCase<Either<Failure, Location>, NoParams> {
  final LocationRepository locationRepository;

  GetCurrentLocationUseCase({required this.locationRepository});

  @override
  Stream<Either<Failure, Location>> call(NoParams params) {
    return locationRepository.getCurrentLocation();
  }
}
