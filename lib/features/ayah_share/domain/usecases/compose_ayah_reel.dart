import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../entities/reel_request.dart';
import '../repositories/reel_repository.dart';

class ComposeAyahReel {
  ComposeAyahReel(this._reels);

  final ReelRepository _reels;

  Future<Either<Failure, String>> call(ReelRequest request) =>
      _reels.compose(request);

  Stream<double> get progress => _reels.progress;

  Future<void> cancel() => _reels.cancel();

  Future<void> discard(String path) => _reels.discard(path);
}
