import 'package:flutter/widgets.dart';
import 'package:intl/intl.dart';
import 'package:quran_app/core/helper functions/locale_helpers.dart';
import 'package:quran_app/core/helper functions/numeral_helpers.dart';
import 'package:quran_app/core/localization/pending_s.dart';
import 'package:quran_app/features/bookmarks/domain/entities/fasil_slot.dart';
import 'package:quran_app/features/bookmarks/domain/entities/place.dart';
import 'package:quran_app/features/bookmarks/presentation/utils/enum_localization.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

String fasilName(BuildContext context, FasilSlot slot, Place? place) =>
    place?.name ?? slot.localized(context);

String ayahPlace(BuildContext context, AyahIdentifier ayah) =>
    '${surahDisplayName(context, ayah.surah)} ${ayah.ayah.toLocalized(context)}';

String placeWhen(
  DateTime at, {
  required DateTime now,
  required String localeCode,
  bool use24h = false,
}) {
  final s = PendingS.forLanguage(localeCode);
  final day = DateTime(at.year, at.month, at.day);
  final today = DateTime(now.year, now.month, now.day);
  final time = DateFormat(
    use24h ? 'H:mm' : 'h:mm a',
    localeCode,
  ).format(at).toIndicNumerals(localeCode);
  final text = switch (today.difference(day).inDays) {
    0 => s.places_today(time),
    1 => s.places_yesterday(time),
    _ => DateFormat(
      at.year == now.year ? 'd MMMM' : 'd MMMM y',
      localeCode,
    ).format(at),
  };
  return text.toIndicNumerals(localeCode);
}
