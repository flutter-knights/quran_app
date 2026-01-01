part of 'ahadith_cubit.dart';

sealed class AhadithState extends Equatable {
  const AhadithState();

  @override
  List<Object> get props => [];
}

final class AhadithInitial extends AhadithState {}

final class AhadithLoading extends AhadithState {}

final class AhadithError extends AhadithState {
  final String message;
  final bool paginationError;
  const AhadithError(this.message, {required this.paginationError});
  @override
  List<Object> get props => [message];
}

final class AhadithLoadingMore extends AhadithState {
  final List<Hadith> oldAhadith;

  const AhadithLoadingMore({required this.oldAhadith});

  @override
  List<Object> get props => [oldAhadith];
}

final class AhadithLoaded extends AhadithState {
  final List<Hadith> ahadith;
  final bool lastPage;

  const AhadithLoaded({required this.ahadith, required this.lastPage});

  @override
  List<Object> get props => [ahadith];
}
