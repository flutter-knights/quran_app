import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/color_scheme.dart';

/// Wraps a scrollable and overlays a mini "scroll to top" FAB that fades in once
/// the user has scrolled past [threshold], and animates the list back to the
/// top on tap. Drop it around any list driven by [controller]:
///
/// ```dart
/// ScrollToTopFab(
///   controller: _scrollController,
///   child: ListView(controller: _scrollController, ...),
/// )
/// ```
class ScrollToTopFab extends StatefulWidget {
  const ScrollToTopFab({
    super.key,
    required this.controller,
    required this.child,
    this.threshold = 400,
  });

  final ScrollController controller;
  final Widget child;
  final double threshold;

  @override
  State<ScrollToTopFab> createState() => _ScrollToTopFabState();
}

class _ScrollToTopFabState extends State<ScrollToTopFab> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onScroll);
  }

  @override
  void didUpdateWidget(ScrollToTopFab oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onScroll);
      widget.controller.addListener(_onScroll);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onScroll);
    super.dispose();
  }

  void _onScroll() {
    final show = widget.controller.hasClients &&
        widget.controller.offset > widget.threshold;
    if (show != _visible) setState(() => _visible = show);
  }

  void _scrollToTop() {
    if (!widget.controller.hasClients) return;
    widget.controller.animateTo(
      0,
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.colorScheme;
    return Stack(
      children: [
        widget.child,
        PositionedDirectional(
          end: 16,
          bottom: 16,
          child: IgnorePointer(
            ignoring: !_visible,
            child: AnimatedScale(
              scale: _visible ? 1 : 0,
              duration: const Duration(milliseconds: 180),
              curve: Curves.easeOutBack,
              child: AnimatedOpacity(
                opacity: _visible ? 1 : 0,
                duration: const Duration(milliseconds: 180),
                child: Material(
                  color: scheme.primary,
                  shape: const CircleBorder(),
                  elevation: 3,
                  shadowColor: Colors.black.withValues(alpha: 0.3),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: _scrollToTop,
                    child: const SizedBox(
                      width: 44,
                      height: 44,
                      child: Icon(
                        Icons.keyboard_arrow_up_rounded,
                        color: Colors.white,
                        size: 26,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
