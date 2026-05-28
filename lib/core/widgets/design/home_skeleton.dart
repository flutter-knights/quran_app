import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';

/// Shimmer placeholder mirroring the home layout (app-bar row, time hero,
/// prayers row, last-read card) while the daily prayer context loads.
class HomeSkeleton extends StatelessWidget {
  const HomeSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    final boxText = TextStyle(fontSize: 14, color: scheme.onSurface);
    final subText = TextStyle(fontSize: 11, color: scheme.onSurfaceVariant);
    return Skeletonizer(
      enabled: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 20, 16, 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('1447 هـ الموافق', style: boxText),
                    const SizedBox(height: 4),
                    Text('المدينة، الدولة', style: subText),
                  ],
                ),
                Container(
                  width: 38,
                  height: 38,
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 28),
            Center(
              child: Text(
                '12:00',
                style: TextStyle(
                  fontSize: 58,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Center(child: Text('متبقٍ على الصلاة القادمة', style: subText)),
            const SizedBox(height: 28),
            Row(
              children: [
                for (int i = 0; i < 5; i++)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 3),
                      child: Column(
                        children: [
                          Text('صلاة', style: TextStyle(fontSize: 10, color: scheme.onSurface)),
                          const SizedBox(height: 8),
                          Container(
                            width: 18,
                            height: 18,
                            decoration: BoxDecoration(
                              color: scheme.surfaceContainer,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text('00:00', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            SurfaceCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('آخر قراءة — الصفحة', style: boxText),
                  const SizedBox(height: 10),
                  Text('متابعة القراءة من حيث توقفت', style: subText),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
