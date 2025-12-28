import '../../../domain/entities/mushaf_page_entity.dart';

abstract class MushafState {}

class MushafInitial extends MushafState {}

class MushafLoading extends MushafState {}

class MushafLoaded extends MushafState {
  final MushafPageEntity pageContent;

  MushafLoaded(this.pageContent);
}

class MushafError extends MushafState {
  final String message;

  MushafError(this.message);
}
