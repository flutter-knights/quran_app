import 'package:quran_app/core/usecases/stream_usecase.dart';
import 'package:quran_app/features/ahadith/domain/entities/download_progress.dart';
import 'package:quran_app/features/ahadith/domain/repositories/ahadith_repository.dart';

class DownloadAhadithBookUseCase
    extends StreamUseCase<DownloadProgress, String> {
  final AhadithRepository ahadithRepository;

  DownloadAhadithBookUseCase({required this.ahadithRepository});
  @override
  Stream<DownloadProgress> call(String bookSlug) {
    return ahadithRepository.downloadAllAhadith(bookSlug);
  }
}
