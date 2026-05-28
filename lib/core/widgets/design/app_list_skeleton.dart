import 'package:flutter/material.dart';
import 'package:skeletonizer/skeletonizer.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/core/widgets/design/surface_card.dart';

/// Shimmer placeholder list for screens that load asynchronously. Drop it
/// straight into a loading branch — no per-field skeleton markup needed.
class AppListSkeleton extends StatelessWidget {
  const AppListSkeleton({super.key, this.count = 7});
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Skeletonizer(
      enabled: true,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 32),
        itemCount: count,
        physics: const NeverScrollableScrollPhysics(),
        separatorBuilder: (_, __) => const SizedBox(height: 10),
        itemBuilder: (_, __) => SurfaceCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'عنوان تجريبي للعنصر قيد التحميل',
                style: TextStyle(fontSize: 16, color: scheme.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'سطر فرعي يوضح حالة التحميل',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
