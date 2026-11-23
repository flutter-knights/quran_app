import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/reel_request.dart';

abstract class ReelRepository {
  Future<Either<Failure, Duration>> audioDuration(String path);
  Future<Either<Failure, String>> compose(ReelRequest request);
  Stream<double> get progress;
  Future<void> cancel();
}
