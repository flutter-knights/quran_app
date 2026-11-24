import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/features/tafsir/domain/entities/tafsir.dart';

const _intro =
    'سورة الفاتحة سميت هذه السورة بالفاتحة؛ لأنه يفتتح بها القرآن العظيم، وتسمى المثاني؛ لأنها تقرأ في كل ركعة، ولها أسماء أخر. أبتدئ قراءة القرآن باسم الله مستعينا به';

void main() {
  test('body drops the Al-Fatiha introduction', () {
    const tafsir = Tafsir(surah: 1, ayah: 1, text: _intro);

    expect(tafsir.body, 'أبتدئ قراءة القرآن باسم الله مستعينا به');
  });

  test('body strips the introduction after a leading space or BOM', () {
    const tafsir = Tafsir(surah: 1, ayah: 1, text: '\u{FEFF}  $_intro');

    expect(tafsir.body, 'أبتدئ قراءة القرآن باسم الله مستعينا به');
  });

  test('body is the text for any other ayah', () {
    const tafsir = Tafsir(surah: 2, ayah: 1, text: _intro);

    expect(tafsir.body, _intro);
  });

  test('1:1 without the introduction stays whole', () {
    const tafsir = Tafsir(
      surah: 1,
      ayah: 1,
      text: 'أبتدئ قراءة القرآن باسم الله. مستعينا به',
    );

    expect(tafsir.body, tafsir.text);
  });

  test('1:1 with the introduction but no full stop stays whole', () {
    const tafsir = Tafsir(
      surah: 1,
      ayah: 1,
      text: 'سورة الفاتحة سميت هذه السورة بالفاتحة',
    );

    expect(tafsir.body, tafsir.text);
  });
}
