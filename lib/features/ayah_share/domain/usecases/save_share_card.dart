import 'dart:typed_data';

import 'package:dartz/dartz.dart';

import '../../../../core/errors/failure.dart';
import '../repositories/reel_repository.dart';

class SaveShareCard {
  SaveShareCard(this._reels);

  final ReelRepository _reels;

  Future<Either<Failure, String>> call(Uint8List png, String fileName) =>
      _reels.saveCard(png, fileName);
}
