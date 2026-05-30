import 'package:quran_app/features/qibla/domain/entities/compass_reading.dart';

abstract class CompassRepository {
  /// Emits a [CompassReading] per sensor sample. On devices without a
  /// magnetometer the stream may emit readings with a null heading or never
  /// emit at all — the cubit handles both.
  Stream<CompassReading> watchHeading();
}
