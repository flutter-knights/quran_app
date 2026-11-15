import 'package:hive_ce/hive.dart';

class NotificationsLocalDataSource {
  static const _iosScheduledUntilKey = 'iosScheduledUntil';

  final String boxName;

  NotificationsLocalDataSource({this.boxName = 'prayerConfig'});

  Box get _box => Hive.box(boxName);

  DateTime? readIosScheduledUntil() {
    final ms = _box.get(_iosScheduledUntilKey);
    return ms is int ? DateTime.fromMillisecondsSinceEpoch(ms) : null;
  }

  Future<void> writeIosScheduledUntil(DateTime? value) => value == null
      ? _box.delete(_iosScheduledUntilKey)
      : _box.put(_iosScheduledUntilKey, value.millisecondsSinceEpoch);
}
