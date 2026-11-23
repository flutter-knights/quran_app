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
import '../../../../core/widgets/design/app_settings_tile.dart';
import '../../../../generated/l10n.dart';
import '../../../quran_playback/domain/entities/ayah_identifier.dart';
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
  }) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    useSafeArea: true,
    backgroundColor: context.colorScheme.surface,
    builder: (_) => BlocProvider(
      create: (_) => sl<AyahShareCubit>(param1: ayah)..load(),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.85,
        builder: (_, controller) =>
            AyahShareSheet(ayah: ayah, controller: controller),
      ),
    ),
  );

  @override
  State<AyahShareSheet> createState() => _AyahShareSheetState();
}

class _AyahShareSheetState extends State<AyahShareSheet> {
  final _shareKey = GlobalKey();
  final _textKey = GlobalKey();

  Rect? _originOf(GlobalKey key) {
    final box = key.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.attached) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  String _label(BuildContext context) => S
      .of(context)
      .ayah_label(
        surahDisplayName(context, widget.ayah.surah),
        widget.ayah.ayah.toLocalized(context),
      );

  void _onExport(BuildContext context, AyahShareState state) {
    switch (state.export) {
      case ShareExport.sharing:
        _shareImage(context, state);
      case ShareExport.failed:
        _showFailure(ScaffoldMessenger.of(context));
      case _:
    }
  }

  void _showFailure(ScaffoldMessengerState messenger) => messenger.showSnackBar(
    SnackBar(content: Text(S.current.share_failed, style: TS.regular14)),
  );

  Future<void> _shareImage(BuildContext context, AyahShareState state) async {
    final cubit = context.read<AyahShareCubit>();
    final bytes = state.cardBytes!;
    final label = _label(context);
    final origin = _originOf(_shareKey);
    var ok = true;
    try {
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile.fromData(bytes, mimeType: 'image/png')],
          fileNameOverrides: [
            'ayah_${widget.ayah.surah}_${widget.ayah.ayah}.png',
          ],
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
    final messenger = ScaffoldMessenger.of(_textKey.currentContext!);
    final text = ayahShareText(context, widget.ayah);
    final origin = _originOf(_textKey);
    try {
      await SharePlus.instance.share(
        ShareParams(text: text, sharePositionOrigin: origin),
      );
    } catch (_) {
      if (mounted) _showFailure(messenger);
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = PendingS.of(context);
    final cubit = context.read<AyahShareCubit>();
    return ScaffoldMessenger(
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: BlocListener<AyahShareCubit, AyahShareState>(
          listenWhen: (a, b) => a.export != b.export,
          listener: _onExport,
          child: ListView(
            controller: widget.controller,
            padding: const EdgeInsets.all(16),
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
                    child: Text(S.of(context).playback_close),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              BlocSelector<
                AyahShareCubit,
                AyahShareState,
                (ShareCardStatus, int, MushafPaper, bool)
              >(
                selector: (state) =>
                    (state.status, state.renderId, state.paper, state.progress),
                builder: (context, selected) {
                  final (status, _, paper, progress) = selected;
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
                          label: Text(s.mushaf_retry),
                          onPressed: cubit.load,
                        ),
                      ],
                    );
                  }
                  return ShareCardPreview(
                    bytes: cubit.state.cardBytes,
                    paper: paper,
                    progress: progress,
                    semanticLabel: _label(context),
                  );
                },
              ),
              const SizedBox(height: 16),
              BlocSelector<
                AyahShareCubit,
                AyahShareState,
                (ShareCardStatus, bool, ShareTafsirStatus)
              >(
                selector: (state) =>
                    (state.status, state.includeTafsir, state.tafsirStatus),
                builder: (context, selected) {
                  final (status, includeTafsir, tafsirStatus) = selected;
                  final ready = status == ShareCardStatus.ready;
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
              const SizedBox(height: 16),
              BlocSelector<
                AyahShareCubit,
                AyahShareState,
                (ShareCardStatus, MushafPaper)
              >(
                selector: (state) => (state.status, state.paper),
                builder: (context, selected) {
                  final (status, paper) = selected;
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
                        enabled: status == ShareCardStatus.ready,
                      ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 16),
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
                        onPressed: status == ShareCardStatus.ready && !busy
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
        ),
      ),
    );
  }
}
