import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/helper%20functions/locale_helpers.dart';
import 'package:quran_app/core/widgets/prettier_tap.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final Widget? leading;
  final Widget? trailing;
  final bool isSliver;
  final double height;
  final AppBarOptions options; // Added this

  const CustomAppBar({
    super.key,
    this.title,
    this.leading,
    this.trailing,
    this.isSliver = false,
    this.height = kToolbarHeight,
    this.options = const AppBarOptions(), // Default values
  });

  @override
  Size get preferredSize => Size.fromHeight(options.expandedHeight ?? height);

  Decoration _getDecoration(BuildContext context) {
    return BoxDecoration(
      color: context.colorScheme.surface,
      border: options.showBottomLine
          ? Border(
              bottom: BorderSide(
                color: context.colorScheme.secondary,
                width: 1,
              ),
            )
          : null, // Freedom to remove the line!
    );
  }

  @override
  Widget build(BuildContext context) {
    final toolbar = _HeaderToolbar(
      title: title,
      leading: leading,
      trailing: trailing,
    );

    if (isSliver) {
      return SliverAppBar(
        backgroundColor: context.colorScheme.surface,
        elevation: 0,
        pinned: options.pinned,
        floating: options.floating,
        snap: options.snap,
        expandedHeight: options.expandedHeight,
        automaticallyImplyLeading: false,
        toolbarHeight: height,
        titleSpacing: 0,
        // Using flexibleSpace or title depending on your preference
        title: Container(
          height: height,
          decoration: _getDecoration(context),
          child: toolbar,
        ),
      );
    }

    return SafeArea(
      bottom: false,
      child: Container(
        height: height,
        decoration: _getDecoration(context),
        child: toolbar,
      ),
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
    final Widget backBtn = leading ?? _AutoBackButton();
    final Widget actionBtn = trailing ?? const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: NavigationToolbar(
        centerMiddle: true,

        leading: context.isArabic ? backBtn : actionBtn,
        middle: title != null
            ? DefaultTextStyle(
                style: TS.extra24.copyWith(
                  color: context.colorScheme.onSurface,
                ),
                child: title!,
              )
            : const SizedBox.shrink(),
        trailing: context.isArabic ? actionBtn : backBtn,
      ),
    );
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

class AppBarOptions {
  final bool pinned;
  final bool floating;
  final bool snap;
  final bool showBottomLine;
  final double? expandedHeight;

  const AppBarOptions({
    this.pinned = true,
    this.floating = false,
    this.snap = false,
    this.showBottomLine = true,
    this.expandedHeight,
  });
}
