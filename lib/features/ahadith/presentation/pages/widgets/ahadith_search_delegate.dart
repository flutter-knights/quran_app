import 'package:flutter/material.dart';

class AhadithSearchDelegate extends SliverPersistentHeaderDelegate {
  final Widget child;
  final double height;
  final bool showBottomLine;

  AhadithSearchDelegate({
    required this.child,
    this.height = 70,
    this.showBottomLine = true,
  });

  @override
  double get minExtent => height;
  @override
  double get maxExtent => height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(
      height: height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surface,
        border: showBottomLine
            ? Border(
                bottom: BorderSide(
                  color: Theme.of(context).colorScheme.secondary,
                  width: 1,
                ),
              )
            : null,
      ),
      child: child,
    );
  }

  @override
  bool shouldRebuild(covariant AhadithSearchDelegate oldDelegate) {
    return oldDelegate.height != height ||
        oldDelegate.showBottomLine != showBottomLine;
  }
}
