import 'dart:convert';
import 'package:flutter/services.dart';

import '../models/surah_model.dart';

abstract class SurahLocalDataSource {
  Future<List<SurahModel>> loadSurahs();
}

class SurahLocalDataSourceImpl implements SurahLocalDataSource {
  @override
  Future<List<SurahModel>> loadSurahs() async {
    final jsonString = await rootBundle.loadString(
      'assets/json/surah_list.json',
    );
    final List data = json.decode(jsonString);

    return data.map((e) => SurahModel.fromJson(e)).toList();
  }
}
