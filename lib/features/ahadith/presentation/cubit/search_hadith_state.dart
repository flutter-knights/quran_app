part of 'search_hadith_cubit.dart';

sealed class SearchHadithState extends Equatable {
  const SearchHadithState();
  

  @override
  List<Object> get props => [];
}

final class SearchHadithInitial extends SearchHadithState {}

final class SearchHadithLoading extends SearchHadithState {}

final class SearchHadithLoaded extends SearchHadithState {
  final List<Hadith> hadithList;

  const SearchHadithLoaded(this.hadithList);
}

final class SearchHadithError extends SearchHadithState {
  final String message;

  const SearchHadithError(this.message);
}
