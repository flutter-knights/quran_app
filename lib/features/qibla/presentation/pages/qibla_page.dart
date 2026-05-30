import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/home/presentation/pages/widgets/location_recovery_card.dart';
import 'package:quran_app/features/qibla/presentation/cubit/qibla_cubit.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_compass_dial.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_degree_readout.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_fallback_card.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_meta_cards.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_skeleton.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_status_pill.dart';
import 'package:quran_app/generated/l10n.dart';

class QiblaPage extends StatelessWidget {
  const QiblaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final s = S.of(context);
    return Scaffold(
      backgroundColor: scheme.surface,
      appBar: AppBar(
        backgroundColor: scheme.surface,
        title: Column(
          children: [
            Text(s.qibla_app_bar_label,
                style: TS.regular12.copyWith(color: scheme.onSurfaceVariant)),
            Text(s.qibla_screen_title,
                style: TS.bold16.copyWith(color: scheme.onSurface)),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: s.qibla_recalibrate,
            icon: const HugeIcon(
                icon: HugeIcons.strokeRoundedRefresh, size: 20),
            onPressed: () => context.read<QiblaCubit>().recalibrate(),
          ),
        ],
      ),
      body: BlocBuilder<QiblaCubit, QiblaState>(
        builder: (context, state) {
          if (state is QiblaLoading || state is QiblaInitial) {
            return const QiblaSkeleton();
          }
          if (state is QiblaError) {
            return _buildError(context, state.failure);
          }
          if (state is QiblaLoaded) {
            return SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(18, 12, 18, 24),
              child: Column(
                children: [
                  QiblaStatusPill(
                    isAligned: state.isAligned,
                    needsCalibration: state.needsCalibration,
                  ),
                  const SizedBox(height: 18),
                  QiblaCompassDial(
                    bearing: state.direction.bearing,
                    trueHeading: state.hasCompass ? state.trueHeading : null,
                    size: 280,
                  ),
                  const SizedBox(height: 18),
                  QiblaDegreeReadout(
                    bearing: state.direction.bearing,
                    rose: state.direction.rose,
                  ),
                  const SizedBox(height: 16),
                  if (!state.hasCompass) ...[
                    QiblaFallbackCard(bearing: state.direction.bearing),
                    const SizedBox(height: 16),
                  ],
                  QiblaMetaCards(
                    locationName: state.locationName,
                    distanceKm: state.direction.distanceKm,
                  ),
                ],
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
    );
  }

  Widget _buildError(BuildContext context, Failure failure) {
    final s = S.of(context);
    if (failure is LocationPermissionDeniedFailure) {
      return LocationRecoveryCard(
        actionLabel: s.home_locationCard_enable,
        onAction: () async {
          await Geolocator.requestPermission();
          if (context.mounted) context.read<QiblaCubit>().recalibrate();
        },
      );
    }
    if (failure is LocationPermissionDeniedForeverFailure) {
      return LocationRecoveryCard(
        actionLabel: s.home_locationCard_openSettings,
        onAction: () => Geolocator.openAppSettings(),
      );
    }
    if (failure is LocationServiceDisabledFailure) {
      return LocationRecoveryCard(
        actionLabel: s.home_locationCard_openSettings,
        onAction: () => Geolocator.openLocationSettings(),
      );
    }
    return Center(child: Text(failure.message));
  }
}
