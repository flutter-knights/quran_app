import 'package:flutter/material.dart';
import 'package:quran_app/features/qibla/domain/entities/compass_rose.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_compass_dial.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_degree_readout.dart';
import 'package:quran_app/features/qibla/presentation/pages/widgets/qibla_meta_cards.dart';
import 'package:skeletonizer/skeletonizer.dart';

class QiblaSkeleton extends StatelessWidget {
  const QiblaSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Skeletonizer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 24, 18, 24),
        child: Column(
          children: [
            QiblaCompassDial(pointerAngle: 0, size: 260),
            const SizedBox(height: 24),
            const QiblaDegreeReadout(bearing: 298, rose: CompassRose.nw),
            const SizedBox(height: 20),
            const QiblaMetaCards(locationName: 'Cairo, Egypt', distanceKm: 1234),
          ],
        ),
      ),
    );
  }
}
