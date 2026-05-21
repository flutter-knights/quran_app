import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../domain/entities/last_read.dart';
import '../../../domain/repositories/last_read_repository.dart';

class LastReadCubit extends Cubit<LastRead?> {
  final LastReadRepository repository;
  late final StreamSubscription<LastRead?> _sub;

  LastReadCubit({required this.repository}) : super(null) {
    repository.get().then((value) {
      if (!isClosed && value != null) emit(value);
    });
    _sub = repository.watch().listen((value) {
      if (!isClosed) emit(value);
    });
  }

  Future<void> save(LastRead value) => repository.save(value);

  @override
  Future<void> close() async {
    await _sub.cancel();
    return super.close();
  }
}
