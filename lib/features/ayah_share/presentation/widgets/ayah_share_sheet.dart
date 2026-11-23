import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../config/theme/color_scheme.dart';
import '../../../../config/theme/typography_styles.dart';
import '../../../../core/constants/mushaf_paper.dart';
import '../../../../core/di/dependency_injection.dart';
import '../../../../core/helper functions/locale_helpers.dart';
import '../../../../core/localization/pending_s.dart';
import '../../../../core/widgets/design/action_buttons_row.dart';
import '../../../../core/widgets/design/app_segmented_selector.dart';
import '../../../../core/widgets/design/app_settings_tile.dart';
import '../../../../generated/l10n.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../quran_playback/domain/entities/reciter.dart';
import '../../../quran_playback/presentation/cubit/playback/playback_cubit.dart';
import '../../../settings/presentation/cubit/settings_cubit.dart';
import '../cubit/ayah_share_cubit.dart';
import '../utils/ayah_share_text.dart';
import 'paper_swatches.dart';
import 'share_card_preview.dart';

class AyahShareSheet extends StatefulWidget {
  const AyahShareSheet({
    super.key,
    required this.ayah,
    required this.controller,
  });

  final AyahIdentifier ayah;
  final ScrollController controller;

  static Future<void> show(
    BuildContext context, {
    required AyahIdentifier ayah,
  }) {
    final paper = context.read<SettingsCubit>().state.settingsModel.mushafPaper;
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      backgroundColor: context.colorScheme.surface,
      builder: (_) => BlocProvider(
        create: (_) => sl<AyahShareCubit>(param1: ayah, param2: paper)..load(),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.85,
          builder: (_, controller) =>
              AyahShareSheet(ayah: ayah, controller: controller),
        ),
      ),
    );
  }

  @override
  State<AyahShareSheet> createState() => _AyahShareSheetState();
}

class _AyahShareSheetState extends State<AyahShareSheet> {
  final _shareKey = GlobalKey();
  final _textKey = GlobalKey();
  var _sharingText = false;

  Rect? _originOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  void _onExport(BuildContext context, AyahShareState state) {
    switch (state.export) {
      case ShareExport.sharing:
        _share(context, state);
      case ShareExport.failed:
        _showFailure(ScaffoldMessenger.of(context));
      case _:
    }
  }

  void _showFailure(ScaffoldMessengerState messenger) => messenger.showSnackBar(
    SnackBar(content: Text(S.current.share_failed, style: TS.regular14)),
  );

  void _onAudioFailed(BuildContext context, AyahShareState state) =>
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            PendingS.current.ayahShare_audioFailed,
            style: TS.regular14,
          ),
        ),
      );

  Future<void> _share(BuildContext context, AyahShareState state) async {
    final cubit = context.read<AyahShareCubit>();
    final reel = state.format == ShareFormat.reel;
    final label = reelShareLabel(
      context,
      widget.ayah,
      reel ? state.reelCount : 1,
    );
    final origin = _originOf(_shareKey);
    var ok = true;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [
            reel
                ? XFile(state.reelPath!, mimeType: 'video/mp4')
                : XFile.fromData(state.cardBytes!, mimeType: 'image/png'),
          ],
          fileNameOverrides: reel
              ? null
              : ['ayah_${widget.ayah.surah}_${widget.ayah.ayah}.png'],
          text: label,
          sharePositionOrigin: origin,
        ),
      );
    } catch (_) {
      ok = false;
    }
    cubit.shareFinished(ok: ok);
  }

  Future<void> _shareText() async {
    if (_sharingText) return;
    _sharingText = true;
    final messenger = ScaffoldMessenger.of(_textKey.currentContext!);
    final text = ayahShareText(context, widget.ayah);
    final origin = _originOf(_textKey);
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      );
    } catch (_) {
      if (mounted) _showFailure(messenger);
    } finally {
      _sharingText = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final cubit = context.read<AyahShareCubit>();
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: MultiBlocListener(
          listeners: [
            BlocListener<AyahShareCubit, AyahShareState>(
              listenWhen: (a, b) => a.export != b.export,
              listener: _onExport,
            ),
            BlocListener<AyahShareCubit, AyahShareState>(
              listenWhen: (a, b) =>
                  a.reelIssue != b.reelIssue &&
                  b.reelIssue == ReelIssue.audioFailed,
              listener: _onAudioFailed,
            ),
          ],
          child: ListView(
            controller: widget.controller,
            padding: EdgeInsets.fromLTRB(
              16,
              16,
              16,
              16 + MediaQuery.paddingOf(context).bottom,
            ),
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          s.ayahShare_title,
                          style: TS.bold16.copyWith(
                            color: context.colorScheme.onSurface,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: Text(
                          S.of(context).playback_close,
                          style: TS.bold14,
                        ),
                      ),
                    ],
                  ),
                  BlocSelector<
                    AyahShareCubit,
                    AyahShareState,
                    (ShareCardStatus, Uint8List?, MushafPaper, bool)
                  >(
                    selector: (state) => (
                      state.status,
                      state.cardBytes,
                      state.paper,
                      state.progress,
                    ),
                    builder: (context, selected) {
                      final (status, bytes, paper, progress) = selected;
                      if (status == ShareCardStatus.failed) {
                        return Column(
                          children: [
                            Text(
                              s.ayahShare_renderFailed,
                              style: TS.medium14.copyWith(
                                color: context.colorScheme.onSurface,
                              ),
                            ),
                            TextButton.icon(
                              key: const ValueKey('share-retry'),
                              icon: const HugeIcon(
                                icon: HugeIcons.strokeRoundedRefresh,
                              ),
                              label: Text(s.mushaf_retry, style: TS.medium14),
                              onPressed: cubit.load,
                            ),
                          ],
                        );
                      }
                      return ShareCardPreview(
                        bytes: bytes,
                        paper: paper,
                        progress: progress,
                        semanticLabel: ayahLabel(
                          context,
                          widget.ayah,
                          S.of(context),
                        ),
                        loading: status == ShareCardStatus.loading,
                      );
                    },
                  ),
                  Column(
                    children: [
                      BlocSelector<
                        AyahShareCubit,
                        AyahShareState,
                        (ShareCardStatus, ShareFormat, bool)
                      >(
                        selector: (state) =>
                            (state.status, state.format, state.busy),
                        builder: (context, selected) {
                          final (status, format, busy) = selected;
                          return AppSegmentedSelector<ShareFormat>(
                            key: const ValueKey('share-format'),
                            expand: true,
                            enabled: status == ShareCardStatus.ready && !busy,
                            selected: format,
                            options: [
                              SegmentOption(
                                value: ShareFormat.image,
                                label: s.ayahShare_image,
                              ),
                              SegmentOption(
                                value: ShareFormat.reel,
                                label: s.ayahShare_reel,
                              ),
                            ],
                            onChanged: (value) => switch (value) {
                              ShareFormat.reel => cubit.selectReel(
                                context.read<PlaybackCubit>().state.reciter,
                              ),
                              ShareFormat.image => cubit.selectImage(),
                            },
                          );
                        },
                      ),
                      const _ReelControls(),
                    ],
                  ),
                  BlocSelector<
                    AyahShareCubit,
                    AyahShareState,
                    (ShareCardStatus, bool, ShareTafsirStatus, bool)
                  >(
                    selector: (state) => (
                      state.status,
                      state.includeTafsir,
                      state.tafsirStatus,
                      state.reelWorking,
                    ),
                    builder: (context, selected) {
                      final (status, includeTafsir, tafsirStatus, working) =
                          selected;
                      final ready = status == ShareCardStatus.ready && !working;
                      final failed = tafsirStatus == ShareTafsirStatus.failed;
                      return AppSettingsTile(
                        title: s.ayahShare_addTafsir,
                        subtitle: failed ? s.tafsir_loadFailed : null,
                        enabled: ready,
                        onTap: () => cubit.setIncludeTafsir(!includeTafsir),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            if (failed)
                              IconButton(
                                key: const ValueKey('share-tafsir-retry'),
                                tooltip: s.mushaf_retry,
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedRefresh,
                                ),
                                onPressed: ready ? cubit.retryTafsir : null,
                              ),
                            Switch(
                              key: const ValueKey('share-tafsir'),
                              value: includeTafsir,
                              onChanged: ready ? cubit.setIncludeTafsir : null,
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  BlocSelector<
                    AyahShareCubit,
                    AyahShareState,
                    (ShareCardStatus, MushafPaper, bool)
                  >(
                    selector: (state) =>
                        (state.status, state.paper, state.reelWorking),
                    builder: (context, selected) {
                      final (status, paper, working) = selected;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            s.display_paper,
                            style: TS.medium14.copyWith(
                              color: context.colorScheme.onSurface,
                            ),
                          ),
                          PaperSwatches(
                            selected: paper,
                            onSelected: cubit.setPaper,
                            enabled:
                                status == ShareCardStatus.ready && !working,
                          ),
                        ],
                      );
                    },
                  ),
                  Column(
                    children: [
                      const _ReelProgress(),
                      BlocSelector<
                        AyahShareCubit,
                        AyahShareState,
                        (ShareCardStatus, bool)
                      >(
                        selector: (state) => (state.status, state.busy),
                        builder: (context, selected) {
                          final (status, busy) = selected;
                          return ActionButtonsRow(
                            children: [
                              ActionBtn.primary(
                                key: _shareKey,
                                icon: const HugeIcon(
                                  icon: HugeIcons.strokeRoundedShare08,
                                ),
                                label: S.of(context).share,
                                onPressed:
                                    status == ShareCardStatus.ready && !busy
                                    ? cubit.requestShare
                                    : null,
                              ),
                              KeyedSubtree(
                                key: _textKey,
                                child: ActionBtn(
                                  key: const ValueKey('share-text'),
                                  icon: const HugeIcon(
                                    icon: HugeIcons.strokeRoundedText,
                                  ),
                                  label: s.ayahShare_textOnly,
                                  onPressed: busy ? null : _shareText,
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReelControls extends StatelessWidget {
  const _ReelControls();

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final cubit = context.read<AyahShareCubit>();
    final caption = TS.regular12.copyWith(
      color: context.colorScheme.onSurfaceVariant,
    );
    return BlocSelector<
      AyahShareCubit,
      AyahShareState,
      (ShareFormat, int, bool, bool, Reciter?, bool)
    >(
      selector: (state) => (
        state.format,
        state.reelCount,
        state.canAddAyah,
        state.canRemoveAyah,
        state.reciter,
        state.reelOverLimit,
      ),
      builder: (context, selected) {
        final (format, count, canAdd, canRemove, reciter, overLimit) = selected;
        if (format != ShareFormat.reel || count == 0) {
          return const SizedBox.shrink();
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.ayahShare_ayahCount,
                    style: TS.medium14.copyWith(
                      color: context.colorScheme.onSurface,
                    ),
                  ),
                ),
                IconButton(
                  key: const ValueKey('reel-minus'),
                  tooltip: s.ayahShare_removeAyah,
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedMinusSign),
                  onPressed: canRemove ? cubit.removeAyah : null,
                ),
                Text(
                  count.toLocalized(context),
                  key: const ValueKey('reel-count'),
                  style: TS.bold16.copyWith(
                    color: context.colorScheme.onSurface,
                  ),
                ),
                IconButton(
                  key: const ValueKey('reel-plus'),
                  tooltip: s.ayahShare_addAyah,
                  icon: const HugeIcon(icon: HugeIcons.strokeRoundedPlusSign),
                  onPressed: canAdd ? cubit.addAyah : null,
                ),
              ],
            ),
            if (reciter != null)
              Text(s.ayahShare_recitedBy(reciter.arabicName), style: caption),
            if (overLimit) Text(s.ayahShare_longClip, style: caption),
          ],
        );
      },
    );
  }
}

class _ReelProgress extends StatelessWidget {
  const _ReelProgress();

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final cubit = context.read<AyahShareCubit>();
    return BlocSelector<AyahShareCubit, AyahShareState, (bool, double, bool)>(
      selector: (state) => (
        state.export == ShareExport.encoding,
        state.encodeProgress,
        state.format == ShareFormat.reel &&
            state.reelIssue == ReelIssue.encodeFailed,
      ),
      builder: (context, selected) {
        final (encoding, value, failed) = selected;
        if (!encoding && !failed) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: encoding
              ? Column(
                  key: const ValueKey('reel-encoding'),
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: 8,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            s.ayahShare_encoding,
                            style: TS.medium14.copyWith(
                              color: context.colorScheme.onSurface,
                            ),
                          ),
                        ),
                        TextButton(
                          key: const ValueKey('reel-cancel'),
                          onPressed: cubit.cancelEncode,
                          child: Text(s.places_cancel, style: TS.medium14),
                        ),
                      ],
                    ),
                    LinearProgressIndicator(value: value),
                  ],
                )
              : Column(
                  children: [
                    Text(
                      s.ayahShare_encodeFailed,
                      style: TS.medium14.copyWith(
                        color: context.colorScheme.onSurface,
                      ),
                    ),
                    TextButton.icon(
                      key: const ValueKey('reel-retry'),
                      icon: const HugeIcon(
                        icon: HugeIcons.strokeRoundedRefresh,
                      ),
                      label: Text(s.mushaf_retry, style: TS.medium14),
                      onPressed: cubit.requestShare,
                    ),
                  ],
                ),
        );
      },
    );
  }
}
