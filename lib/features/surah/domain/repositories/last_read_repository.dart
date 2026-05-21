import '../entities/last_read.dart';

abstract class LastReadRepository {
  Future<void> save(LastRead value);
  Future<LastRead?> get();
  Stream<LastRead?> watch();
}
