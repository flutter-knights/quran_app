import 'dart:async';
import 'dart:io' show Platform;

import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/home/domain/entities/location.dart';
import 'package:quran_app/features/home/domain/usecases/get_current_location.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_reading.dart';
import 'package:quran_app/features/qibla/domain/entities/qibla_direction.dart';
import 'package:quran_app/features/qibla/domain/usecases/get_magnetic_declination.dart';
import 'package:quran_app/features/qibla/domain/usecases/get_qibla_direction.dart';
import 'package:quran_app/features/qibla/domain/usecases/watch_compass_heading.dart';
import 'package:quran_app/features/qibla/domain/utils/qibla_calculator.dart';

part 'qibla_state.dart';

class QiblaCubit extends Cubit<QiblaState> {
  QiblaCubit({
    required this.getCurrentLocation,
    required this.getQiblaDirection,
    required this.getMagneticDeclination,
    required this.watchCompassHeading,
    DateTime Function()? now,
    bool? rawHeadingIsTrue,
    this.sensorTimeout = const Duration(seconds: 4),
  })  : _now = now ?? DateTime.now,
        _rawHeadingIsTrue = rawHeadingIsTrue ?? Platform.isIOS,
        super(const QiblaInitial());

  final GetCurrentLocationUseCase getCurrentLocation;
  final GetQiblaDirection getQiblaDirection;
  final GetMagneticDeclination getMagneticDeclination;
  final WatchCompassHeading watchCompassHeading;
  final Duration sensorTimeout;

  final DateTime Function() _now;
  final bool _rawHeadingIsTrue;

  StreamSubscription<dynamic>? _locationSub;
  StreamSubscription<CompassReading>? _compassSub;
  Timer? _sensorTimer;
  double _declination = 0;

  /// Entry point — call once when the page mounts.
  Future<void> start() async {
    emit(const QiblaLoading());
    await _locationSub?.cancel();
    _locationSub = getCurrentLocation(NoParams()).listen((result) {
      if (isClosed) return;
      result.fold(
        (failure) => emit(QiblaError(failure)),
        _onLocation,
      );
    });
  }

  /// Re-run the whole pipeline (recalibrate button).
  Future<void> recalibrate() => start();

  Future<void> _onLocation(Location location) async {
    final direction = await getQiblaDirection(location);
    _declination = await getMagneticDeclination(DeclinationParams(
      latitude: location.latitude,
      longitude: location.longitude,
      date: _now(),
    ));
    if (isClosed) return;

    emit(QiblaLoaded(
      direction: direction,
      locationName: _locationName(location),
      hasCompass: true, // optimistic; flipped false on null/timeout
    ));

    _listenToCompass();
  }

  void _listenToCompass() {
    _sensorTimer?.cancel();
    _compassSub?.cancel();

    // No reading within the timeout => treat as "no compass".
    _sensorTimer = Timer(sensorTimeout, () {
      final s = state;
      if (!isClosed && s is QiblaLoaded && s.trueHeading == null) {
        emit(s.copyWith(hasCompass: false));
      }
    });

    _compassSub = watchCompassHeading(NoParams()).listen((reading) {
      if (isClosed) return;
      final s = state;
      if (s is! QiblaLoaded) return;

      if (!reading.hasHeading) {
        _sensorTimer?.cancel();
        emit(s.copyWith(hasCompass: false));
        return;
      }

      _sensorTimer?.cancel();
      final trueHeading = QiblaCalculator.toTrueHeading(
        reading.heading!,
        declination: _declination,
        rawIsTrue: _rawHeadingIsTrue,
      );
      emit(s.copyWith(
        trueHeading: trueHeading,
        accuracy: reading.accuracy,
        hasCompass: true,
      ));
    });
  }

  String? _locationName(Location l) {
    final city = l.city ?? l.enCity;
    final country = l.country ?? l.enCountry;
    if (city != null && country != null) return '$city، $country';
    return city ?? country;
  }

  @override
  Future<void> close() {
    _locationSub?.cancel();
    _compassSub?.cancel();
    _sensorTimer?.cancel();
    return super.close();
  }
}
