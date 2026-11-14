import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:quran_app/features/home/data/datasources/local/prayer_config_signature.dart';

void main() {
  late Box box;
  setUp(() async {
    Hive.init('./.dart_tool/hive_test_${DateTime.now().microsecondsSinceEpoch}');
    box = await Hive.openBox('prayerConfig_test');
  });
  tearDown(() async => box.deleteFromDisk());

  test('signature is stable for same inputs and rounds coordinates', () {
    final a = buildPrayerConfigSignature(
        latitude: 30.044, longitude: 31.235, method: 5, school: 0);
    final b = buildPrayerConfigSignature(
        latitude: 30.0441, longitude: 31.2349, method: 5, school: 0);
    expect(a, b); // rounded to 1dp -> identical
  });

  test('signature changes when method or school changes', () {
    final base = buildPrayerConfigSignature(
        latitude: 30.04, longitude: 31.23, method: 5, school: 0);
    final diffMethod = buildPrayerConfigSignature(
        latitude: 30.04, longitude: 31.23, method: 3, school: 0);
    final diffSchool = buildPrayerConfigSignature(
        latitude: 30.04, longitude: 31.23, method: 5, school: 1);
    expect(base, isNot(diffMethod));
    expect(base, isNot(diffSchool));
  });

  test('hasChangedAndStore returns true on first call, false on repeat', () {
    final store = PrayerConfigSignatureStore(box: box);
    expect(store.hasChangedAndStore('sig-1'), isTrue);
    expect(store.hasChangedAndStore('sig-1'), isFalse);
    expect(store.hasChangedAndStore('sig-2'), isTrue);
  });
}
