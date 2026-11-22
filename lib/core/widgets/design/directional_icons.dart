import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';

/// Returns the "back" arrow that points toward the start of the reading
/// direction: right-pointing in RTL (Arabic), left-pointing in LTR (English).
List<List<dynamic>> backArrowIcon(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
        ? HugeIcons.strokeRoundedArrowRight02
        : HugeIcons.strokeRoundedArrowLeft02;

/// Returns the "forward"/continue arrow that points toward the end of the
/// reading direction: left-pointing in RTL, right-pointing in LTR.
List<List<dynamic>> forwardArrowIcon(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
        ? HugeIcons.strokeRoundedArrowLeft02
        : HugeIcons.strokeRoundedArrowRight02;

IconData skipBackIcon(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
        ? Icons.skip_next
        : Icons.skip_previous;

IconData skipForwardIcon(BuildContext context) =>
    Directionality.of(context) == TextDirection.rtl
        ? Icons.skip_previous
        : Icons.skip_next;
