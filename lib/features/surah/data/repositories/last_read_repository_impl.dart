import '../../../quran_playback/domain/entities/ayah_identifier.dart';
import '../../domain/entities/last_read.dart';
import '../../domain/repositories/last_read_repository.dart';
import '../datasources/last_read_local_data_source.dart';
import '../models/last_read_hive_model.dart';

class LastReadRepositoryImpl implements LastReadRepository {
  final LastReadLocalDataSource local;
  LastReadRepositoryImpl({required this.local});

  LastRead? _from(LastReadHiveModel? m) {
    if (m == null) return null;
    final ayah = (m.surah != null && m.ayah != null)
        ? AyahIdentifier(surah: m.surah!, ayah: m.ayah!)
        : null;
    return LastRead(page: m.page, ayah: ayah);
  }

  LastReadHiveModel _to(LastRead v) => LastReadHiveModel(
        page: v.page,
        surah: v.ayah?.surah,
        ayah: v.ayah?.ayah,
      );

  @override
  Future<void> save(LastRead value) => local.save(_to(value));

  @override
  Future<LastRead?> get() async => _from(local.get());

  @override
  Stream<LastRead?> watch() => local.watch().map((_) => _from(local.get()));
}
