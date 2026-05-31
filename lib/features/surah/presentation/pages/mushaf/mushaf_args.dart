import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';

/// Navigation payload for `/mushaf`. Existing callers still pass a bare `int`
/// page (handled by the router's backward-compatible parser); search results
/// pass [focusAyah] to highlight a specific verse on arrival.
class MushafArgs {
  final int page;
  final AyahIdentifier? focusAyah;
  const MushafArgs({required this.page, this.focusAyah});
}
