import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

class SearchDelegateBehavior extends SliverPersistentHeaderDelegate {
  SearchDelegateBehavior({
    required this.maxHeight,
    required this.minHeight,
    required this.child,
  });

  final double maxHeight;
  final double minHeight;
  final Widget child;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            context.colorScheme.surface,
            context.colorScheme.surface.withValues(alpha: 0),
          ],
          end: Alignment.bottomCenter,
          begin: Alignment.topCenter,
          stops: const [0.9, 1],
        ),
      ),
      child: SizedBox.expand(child: child),
    );
  }

  @override
  double get maxExtent => maxHeight;
  @override
  double get minExtent => minHeight;

  @override
  bool shouldRebuild(covariant SliverPersistentHeaderDelegate oldDelegate) {
    return true;
  }
}
