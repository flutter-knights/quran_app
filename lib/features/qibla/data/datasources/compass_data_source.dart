import 'package:flutter_compass/flutter_compass.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_reading.dart';

class CompassDataSource {
  /// Defaults to the real plugin stream; injectable for tests.
  CompassDataSource({Stream<CompassEvent?>? events})
      : _events = events ?? FlutterCompass.events;

  final Stream<CompassEvent?>? _events;

  Stream<CompassReading> headingStream() {
    final source = _events;
    if (source == null) {
      // Plugin reports the platform has no compass support at all.
      return Stream.value(const CompassReading(heading: null));
    }
    return source.map(
      (e) => CompassReading(heading: e?.heading, accuracy: e?.accuracy),
    );
  }
}
