import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/core/usecases/usecase.dart';
import 'package:quran_app/features/notifications/domain/usecases/get_android_sdk_int.dart';

class AndroidSdkCubit extends Cubit<int?> {
  AndroidSdkCubit(this._getSdkInt) : super(null);

  final GetAndroidSdkInt _getSdkInt;

  Future<void> load() async {
    final result = await _getSdkInt(NoParams());
    if (isClosed) return;
    result.fold((_) {}, (sdk) {
      if (sdk != null) emit(sdk);
    });
  }
}
