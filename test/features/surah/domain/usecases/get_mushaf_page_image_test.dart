import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import 'package:quran_app/features/surah/domain/repositories/mushaf_repo.dart';
import 'package:quran_app/features/surah/domain/usecases/get_mushaf_page.dart';

class _StubRepo implements MushafRepository {
  _StubRepo(this._result);
  final Either<Failure, MushafPageEntity> _result;
  @override
  Future<Either<Failure, MushafPageEntity>> getPage(int _) async =>
      _result;
}

void main() {
  test('forwards page number to repository', () async {
    const entity = MushafPageEntity(pageNumber: 7, ayahs: []);
    final useCase = GetMushafPage(_StubRepo(const Right(entity)));
    final result = await useCase(7);
    result.fold(
      (_) => fail('expected right'),
      (e) => expect(e.pageNumber, 7),
    );
  });
}
