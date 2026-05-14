import 'package:flutter/material.dart';

import '../../../domain/entities/mushaf_page_entity.dart';

sealed class MushafState {
  const MushafState();
}

final class MushafInitial extends MushafState {
  const MushafInitial();
}

final class MushafLoading extends MushafState {
  const MushafLoading();
}

final class MushafError extends MushafState {
  const MushafError(this.message);
  final String message;
}

final class MushafLoaded extends MushafState {
  const MushafLoaded({
    required this.page,
    required this.spans,
    required this.normalStyle,
    required this.highlightedStyle,
    required this.pageWidth,
    required this.fontSize,
    required this.lineHeight,
  });

  final MushafPageEntity page;
  final List<InlineSpan> spans;
  final TextStyle normalStyle;
  final TextStyle highlightedStyle;
  final double pageWidth;
  final double fontSize;
  final double lineHeight;
}
