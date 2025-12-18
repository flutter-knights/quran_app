import 'package:dartz/dartz.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';

import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/repositories/location_repository.dart';

class GetCurrentLocationUseCase
    extends UseCase<Either<Failure, Location>, NoParams> {
  final LocationRepository locationRepository;

  GetCurrentLocationUseCase({required this.locationRepository});
  @override
  Future<Either<Failure, Location>> call(_) async {
    return await locationRepository.getCurrentLocation();
  }
}
