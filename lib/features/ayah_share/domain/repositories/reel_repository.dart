import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/reel_request.dart';

abstract class ReelRepository {
  Future<Either<Failure, Duration>> audioDuration(String path);
  Future<Either<Failure, String>> compose(ReelRequest request);
  Future<Either<Failure, String>> saveCard(Uint8List png, String fileName);
  Stream<double> get progress;
  Future<void> cancel();
  Future<void> discard(String path);
}
