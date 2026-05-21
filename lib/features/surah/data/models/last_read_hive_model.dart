import 'package:hive/hive.dart';

part 'last_read_hive_model.g.dart';

@HiveType(typeId: 5)
class LastReadHiveModel extends HiveObject {
  @HiveField(0)
  int page;

  @HiveField(1)
  int? surah;

  @HiveField(2)
  int? ayah;

  LastReadHiveModel({required this.page, this.surah, this.ayah});
}
