import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../cubit/tafsir_cubit.dart';

const _placeholder = 'هذا نص تفسير مؤقت يملأ السطر';

class TafsirSection extends StatelessWidget {
  const TafsirSection({
    super.key,
    required this.ayah,
    required this.ink,
    required this.mutedInk,
    required this.buttonStyle,
    this.lead = false,
    this.onTap,
  });

  final AyahIdentifier ayah;
  final Color ink;
  final Color mutedInk;
  final ButtonStyle buttonStyle;
  final bool lead;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    return BlocSelector<TafsirCubit, TafsirState, TafsirState>(
      selector: (state) => switch (state) {
        TafsirLoaded(ayah: final a) ||
        TafsirFailed(ayah: final a) when a == ayah => state,
        _ => TafsirLoading(ayah),
      },
      builder: (context, state) {
        final onRetry = context.read<TafsirCubit>().retry;
        final glyph = HugeIcon(
          icon: HugeIcons.strokeRoundedRefresh,
          color: ink,
          size: lead ? 22 : 18,
        );
        final retry = lead
            ? IconButton(
                key: const ValueKey('tafsir-retry'),
                tooltip: s.mushaf_retry,
                style: buttonStyle,
                onPressed: onRetry,
                icon: glyph,
              )
            : TextButton.icon(
                key: const ValueKey('tafsir-retry'),
                style: buttonStyle,
                onPressed: onRetry,
                icon: glyph,
                label: Text(s.mushaf_retry, style: TS.semi14),
              );
        return lead ? _lead(state, s, retry) : _full(state, s, retry);
      },
    );
  }

  Widget _lead(TafsirState state, PendingS s, Widget retry) {
    final muted = TS.regular14.copyWith(color: mutedInk);
    return InkWell(
      onTap: onTap,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 48),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: switch (state) {
            TafsirLoaded(:final tafsir) => Text(
              tafsir.text,
              textDirection: TextDirection.rtl,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: muted,
            ),
            TafsirFailed() => Semantics(
              liveRegion: true,
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      s.tafsir_loadFailed,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TS.medium14.copyWith(color: ink),
                    ),
                  ),
                  retry,
                ],
              ),
            ),
            _ => Skeletonizer(
              child: Text(
                _placeholder,
                textDirection: TextDirection.rtl,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: muted,
              ),
            ),
          },
        ),
      ),
    );
  }

  Widget _full(TafsirState state, PendingS s, Widget retry) {
    final body = TS.regular16.copyWith(height: 1.95, color: ink);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 8,
      children: [
        Text(s.tafsir_muyassar, style: TS.bold16.copyWith(color: ink)),
        Text(
          s.tafsir_bookCaption,
          style: TS.regular14.copyWith(color: mutedInk),
        ),
        Text(s.tafsir_source, style: TS.regular14.copyWith(color: mutedInk)),
        switch (state) {
          TafsirLoaded(:final tafsir) => Text(
            tafsir.text,
            key: const ValueKey('tafsir-body'),
            textDirection: TextDirection.rtl,
            style: body,
          ),
          TafsirFailed() => Semantics(
            liveRegion: true,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    s.tafsir_loadFailed,
                    style: TS.medium14.copyWith(color: ink),
                  ),
                ),
                retry,
              ],
            ),
          ),
          _ => Skeletonizer(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < 4; i++)
                  Text(
                    _placeholder,
                    textDirection: TextDirection.rtl,
                    style: body,
                  ),
              ],
            ),
          ),
        },
      ],
    );
  }
}
