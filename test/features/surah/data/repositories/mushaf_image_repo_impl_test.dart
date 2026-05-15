import 'package:dartz/dartz.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:quran_app/core/errors/failure.dart';
import 'package:quran_app/features/surah/data/datasources/mushaf_local_data_source.dart';
import 'package:quran_app/features/surah/data/models/mushaf_page_model.dart';
import 'package:quran_app/features/surah/data/repositories/mushaf_repo_impl.dart';

class _StubDataSource extends MushafLocalDataSource {
  _StubDataSource(this._result);
  final Object _result;
  @override
  Future<MushafPageModel> getPage(int pageNumber) async {
    final r = _result;
    if (r is Exception) throw r;
    return r as MushafPageModel;
  }
}

void main() {
  test('returns Right on success', () async {
    final model = MushafPageModel.fromJson({
      'page': 2,
      'ayahs': [
        {
          'surah': 2,
          'ayah': 1,
          'lines': [
            {'x': 0.0, 'y': 0.0, 'w': 0.1, 'h': 0.05},
          ],
        },
      ],
    });
    final repo = MushafRepositoryImpl(dataSource: _StubDataSource(model));
    final result = await repo.getPage(2);
    expect(result, isA<Right<Failure, dynamic>>());
    result.fold((_) => fail('expected right'), (e) {
      expect(e.pageNumber, 2);
    });
  });

  test('maps exception to CacheFailure', () async {
    final repo = MushafRepositoryImpl(
      dataSource: _StubDataSource(Exception('boom')),
    );
    final result = await repo.getPage(99);
    expect(result, isA<Left<Failure, dynamic>>());
    result.fold(
      (f) => expect(f, isA<CacheFailure>()),
      (_) => fail('expected left'),
    );
  });
}
