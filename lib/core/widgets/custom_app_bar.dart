import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final Widget? trailing;
  final bool isSliver;
  final double height;

  const CustomAppBar({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.isSliver = false,
    this.height = kToolbarHeight,
  });

  @override
  Size get preferredSize => Size.fromHeight(height);

  @override
  Widget build(BuildContext context) {
    final toolbar = _HeaderToolbar(
      title: title,
      leading: leading,
      trailing: trailing,
    );

    if (isSliver) {
      return SliverAppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        shadowColor: Colors.transparent,
        pinned: true,
        automaticallyImplyLeading: false,
        toolbarHeight: height,
        titleSpacing: 0,
        title: toolbar,
      );
    }

    return SafeArea(
      bottom: false,
      child: SizedBox(height: height, child: toolbar),
    );
  }
}

class _HeaderToolbar extends StatelessWidget {
  final Widget? title;
  final Widget? leading;
  final Widget? trailing;

  const _HeaderToolbar({
    required this.title,
    required this.leading,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: NavigationToolbar(
        centerMiddle: true,
        leading: leading != null
            ? _SmartStyle.apply(context, leading!)
            : _AutoBackButton(),
        middle: title != null
            ? DefaultTextStyle(
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
                child: title!,
              )
            : const SizedBox.shrink(),
        trailing: trailing != null
            ? _SmartStyle.apply(context, trailing!)
            : const SizedBox.shrink(),
      ),
    );
  }
}

class _SmartStyle {
  static Widget apply(BuildContext context, Widget child) {
    final resolved = _unwrap(child);

    if (resolved is Icon || resolved is IconButton) {
      return IconTheme(
        data: const IconThemeData(color: Colors.teal, size: 28),
        child: child,
      );
    }

    if (resolved is Text || resolved is TextButton) {
      return DefaultTextStyle.merge(
        style: const TextStyle(
          color: Colors.teal,
          fontSize: 16,
          fontWeight: FontWeight.bold,
        ),
        child: child,
      );
    }

    return child;
  }

  static Widget _unwrap(Widget widget) {
    if (widget is GestureDetector && widget.child != null) {
      return _unwrap(widget.child!);
    }
    if (widget is InkWell && widget.child != null) {
      return _unwrap(widget.child!);
    }
    return widget;
  }
}

class _AutoBackButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final isRTL = Directionality.of(context) == TextDirection.rtl;

    return PrettierTap(
      child: HugeIcon(
        size: 32,
        icon: isRTL
            ? HugeIcons.strokeRoundedArrowRight01
            : HugeIcons.strokeRoundedArrowLeft01,
      ),
      onTap: () => GoRouter.of(context).pop(),
    );
  }
}
