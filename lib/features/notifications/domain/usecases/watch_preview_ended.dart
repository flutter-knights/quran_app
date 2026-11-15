import 'package:quran_app/core/usecases/stream_usecase.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/entities/preview_sound.dart';
import 'package:quran_app/features/notifications/domain/repositories/notifications_repository.dart';

class WatchPreviewEnded extends StreamUseCase<PreviewSound, NoParams> {
  WatchPreviewEnded({required this.repository});

  final NotificationsRepository repository;

  @override
  Stream<PreviewSound> call(NoParams params) => repository.previewEnded();
}
