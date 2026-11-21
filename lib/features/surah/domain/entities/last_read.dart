import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';

class LastRead extends Equatable {
  final int page;
  final AyahIdentifier? ayah;
  final DateTime? updatedAt;

  const LastRead({required this.page, this.ayah, this.updatedAt});

  @override
  List<Object?> get props => [page, ayah, updatedAt];
}
