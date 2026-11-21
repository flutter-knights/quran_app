import 'package:equatable/equatable.dart';

sealed class SurahDownloadStatus extends Equatable {
  const SurahDownloadStatus();

  @override
  List<Object?> get props => [];
}

final class SurahNotDownloaded extends SurahDownloadStatus {
  const SurahNotDownloaded();
}

final class SurahDownloading extends SurahDownloadStatus {
  const SurahDownloading(this.progress);

  final double progress;

  @override
  List<Object?> get props => [progress];
}

final class SurahDownloaded extends SurahDownloadStatus {
  const SurahDownloaded();
}

final class SurahDownloadFailed extends SurahDownloadStatus {
  const SurahDownloadFailed();
}

class SurahDownloadState extends Equatable {
  const SurahDownloadState({this.statuses = const {}});

  final Map<String, SurahDownloadStatus> statuses;

  @override
  List<Object?> get props => [statuses];
}
