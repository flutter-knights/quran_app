import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../data/datasources/mushaf_page_cache.dart';
import '../../../data/datasources/mushaf_spans_cache.dart';
import '../../../domain/entities/mushaf_page_entity.dart';
import '../../../domain/usecases/get_mushaf_page.dart';
import '../../pages/mushaf/widgets/ayah_text_span_builder.dart';
import 'mushaf_state.dart';

class MushafCubit extends Cubit<MushafState> {
  MushafCubit({
    required this.useCase,
    required this.pageCache,
    required this.spansCache,
  }) : super(const MushafInitial());

  final GetMushafPage useCase;
  final MushafPageCache pageCache;
  final MushafSpansCache spansCache;

  /// Synchronous warm-path load. Returns true if both caches hit and a
  /// MushafLoaded was emitted. Returns false if async load is needed.
  bool loadPageSync({
    required int pageNumber,
    required ColorScheme colorScheme,
    required double fontSize,
    required double lineHeight,
    required double pageWidth,
    required BuildContext? builderContext,
  }) {
    final entity = pageCache.get(pageNumber);
    final spans = spansCache.get(pageNumber);
    if (entity == null) return false;
    if (spans != null) {
      return _emitLoadedWithCachedSpans(
        entity: entity,
        spans: spans,
        colorScheme: colorScheme,
        fontSize: fontSize,
        lineHeight: lineHeight,
        pageWidth: pageWidth,
        pageNumber: pageNumber,
      );
    }
    if (builderContext != null) {
      return _emitLoadedFromEntity(
        entity: entity,
        colorScheme: colorScheme,
        fontSize: fontSize,
        lineHeight: lineHeight,
        pageWidth: pageWidth,
        builderContext: builderContext,
        pageNumber: pageNumber,
      );
    }
    return false;
  }

  Future<void> loadPage({
    required int pageNumber,
    required ColorScheme colorScheme,
    required double fontSize,
    required double lineHeight,
    required double pageWidth,
    required BuildContext? builderContext,
  }) async {
    if (isClosed) return;
    emit(const MushafLoading());
    final result = await useCase.call(pageNumber);
    if (isClosed) return;
    result.fold(
      (failure) => emit(MushafError(failure.message)),
      (entity) {
        if (builderContext == null || !builderContext.mounted) {
          emit(MushafLoaded(
            page: entity,
            spans: const <InlineSpan>[],
            normalStyle: _normalStyle(colorScheme, fontSize, lineHeight, pageNumber),
            highlightedStyle: _highlightedStyle(colorScheme, fontSize, lineHeight, pageNumber),
            pageWidth: pageWidth,
            fontSize: fontSize,
            lineHeight: lineHeight,
          ));
          return;
        }
        _emitLoadedFromEntity(
          entity: entity,
          colorScheme: colorScheme,
          fontSize: fontSize,
          lineHeight: lineHeight,
          pageWidth: pageWidth,
          builderContext: builderContext,
          pageNumber: pageNumber,
        );
      },
    );
  }

  bool _emitLoadedFromEntity({
    required MushafPageEntity entity,
    required ColorScheme colorScheme,
    required double fontSize,
    required double lineHeight,
    required double pageWidth,
    required BuildContext builderContext,
    required int pageNumber,
  }) {
    if (isClosed) return false;
    final normalStyle = _normalStyle(colorScheme, fontSize, lineHeight, pageNumber);
    final spans = AyahTextSpanBuilder.buildBase(
      context: builderContext,
      page: entity,
      pageNumber: pageNumber,
      fontSize: fontSize,
      lineHeight: lineHeight,
      pageWidth: pageWidth,
      normalStyle: normalStyle,
    );
    spansCache.put(pageNumber, spans);
    emit(MushafLoaded(
      page: entity,
      spans: spans,
      normalStyle: normalStyle,
      highlightedStyle: _highlightedStyle(colorScheme, fontSize, lineHeight, pageNumber),
      pageWidth: pageWidth,
      fontSize: fontSize,
      lineHeight: lineHeight,
    ));
    return true;
  }

  bool _emitLoadedWithCachedSpans({
    required MushafPageEntity entity,
    required List<InlineSpan> spans,
    required ColorScheme colorScheme,
    required double fontSize,
    required double lineHeight,
    required double pageWidth,
    required int pageNumber,
  }) {
    if (isClosed) return false;
    emit(MushafLoaded(
      page: entity,
      spans: spans,
      normalStyle: _normalStyle(colorScheme, fontSize, lineHeight, pageNumber),
      highlightedStyle: _highlightedStyle(colorScheme, fontSize, lineHeight, pageNumber),
      pageWidth: pageWidth,
      fontSize: fontSize,
      lineHeight: lineHeight,
    ));
    return true;
  }

  TextStyle _normalStyle(
    ColorScheme cs,
    double fontSize,
    double lineHeight,
    int pageNumber,
  ) =>
      TextStyle(
        fontFamily: 'QCF_P${pageNumber.toString().padLeft(3, '0')}',
        fontSize: fontSize,
        height: lineHeight / fontSize,
        color: cs.onSurface,
      );

  TextStyle _highlightedStyle(
    ColorScheme cs,
    double fontSize,
    double lineHeight,
    int pageNumber,
  ) =>
      _normalStyle(cs, fontSize, lineHeight, pageNumber).copyWith(
        color: cs.onPrimary,
        backgroundColor: cs.primary,
      );

  @visibleForTesting
  void seedForTest(MushafState state) {
    if (!isClosed) emit(state);
  }
}
