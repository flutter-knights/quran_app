part of 'tafsir_cubit.dart';

sealed class TafsirState extends Equatable {
  const TafsirState();

  @override
  List<Object?> get props => [];
}

final class TafsirIdle extends TafsirState {
  const TafsirIdle();
}

final class TafsirLoading extends TafsirState {
  const TafsirLoading(this.ayah);

  final AyahIdentifier ayah;

  @override
  List<Object?> get props => [ayah];
}

final class TafsirLoaded extends TafsirState {
  const TafsirLoaded(this.ayah, this.tafsir);

  final AyahIdentifier ayah;
  final Tafsir tafsir;

  @override
  List<Object?> get props => [ayah, tafsir];
}

final class TafsirFailed extends TafsirState {
  const TafsirFailed(this.ayah);

  final AyahIdentifier ayah;

  @override
  List<Object?> get props => [ayah];
}
