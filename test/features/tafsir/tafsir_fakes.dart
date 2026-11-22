import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/features/quran_playback/domain/entities/ayah_identifier.dart';
import 'package:quran_app/features/tafsir/domain/entities/tafsir.dart';
import 'package:quran_app/features/tafsir/presentation/cubit/tafsir_cubit.dart';

const tafsirText =
    'هذا نص تفسير تجريبي طويل يكفي لأن يملأ أكثر من سطر واحد في الورقة';

class FakeTafsirCubit extends Cubit<TafsirState> implements TafsirCubit {
  FakeTafsirCubit([super.initial = const TafsirIdle()]);

  final loads = <AyahIdentifier>[];
  var retries = 0;
  var cancels = 0;
  var failNext = false;

  void push(TafsirState s) => emit(s);

  @override
  Future<void> load(AyahIdentifier ayah) async {
    loads.add(ayah);
    if (ayah.ayah == 0) {
      emit(const TafsirIdle());
      return;
    }
    if (failNext) {
      emit(TafsirFailed(ayah));
      return;
    }
    emit(
      TafsirLoaded(
        ayah,
        Tafsir(surah: ayah.surah, ayah: ayah.ayah, text: tafsirText),
      ),
    );
  }

  @override
  Future<void> retry() async {
    retries++;
    final current = state;
    if (current is TafsirFailed) await load(current.ayah);
  }

  @override
  void cancel() {
    cancels++;
    if (state is TafsirLoading) emit(const TafsirIdle());
  }
}
