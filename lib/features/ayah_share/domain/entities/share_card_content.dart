import 'package:equatable/equatable.dart';

import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../../surah/domain/entities/ayah_bound_entity.dart';

class ShareCardContent extends Equatable {
  const ShareCardContent({
    required this.ayah,
    required this.page,
    required this.pageBounds,
    required this.startPage,
    required this.startPageBounds,
  });

  final AyahIdentifier ayah;
  final int page;
  final List<AyahBoundEntity> pageBounds;
  final int startPage;
  final List<AyahBoundEntity> startPageBounds;

  @override
  List<Object> get props => [
    ayah,
    page,
    pageBounds,
    startPage,
    startPageBounds,
  ];
}
