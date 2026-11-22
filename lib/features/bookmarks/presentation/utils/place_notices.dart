import 'package:flutter/material.dart';
import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/generated/l10n.dart';

void showPlaceNotice(
  ScaffoldMessengerState messenger,
  String message, {
  VoidCallback? onUndo,
}) => messenger
  ..hideCurrentSnackBar()
  ..showSnackBar(
    SnackBar(
      content: Text(message, style: TS.regular14),
      persist:
          onUndo != null &&
          MediaQuery.accessibleNavigationOf(messenger.context),
      action: onUndo == null
          ? null
          : SnackBarAction(label: S.current.undo, onPressed: onUndo),
    ),
  );

void showPlaceWriteError(ScaffoldMessengerState messenger) =>
    showPlaceNotice(messenger, PendingS.current.places_writeFailed);
