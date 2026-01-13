import 'package:flutter/material.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';
import 'package:quran_app/features/ahadith/presentation/pages/widgets/hadith_view.dart';

class HadithPage extends StatelessWidget {
  final Hadith hadith;
  const HadithPage({super.key, required this.hadith});

  @override
  Widget build(BuildContext context) {
    return HadithView(hadith: hadith);
  }
}
