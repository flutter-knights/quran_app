import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';

class LastRead extends Equatable {
  final int page;
  final AyahIdentifier? ayah;

  const LastRead({required this.page, this.ayah});

  @override
  List<Object?> get props => [page, ayah];
}
