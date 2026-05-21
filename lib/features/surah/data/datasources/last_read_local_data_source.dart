import 'package:hive/hive.dart';

import '../models/last_read_hive_model.dart';

class LastReadLocalDataSource {
  static const _key = 'current';
  final Box<LastReadHiveModel> box;

  LastReadLocalDataSource({required this.box});

  Future<void> save(LastReadHiveModel model) => box.put(_key, model);

  LastReadHiveModel? get() => box.get(_key);

  Stream<BoxEvent> watch() => box.watch(key: _key);
}
