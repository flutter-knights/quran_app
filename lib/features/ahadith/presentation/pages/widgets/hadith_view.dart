import 'package:flutter/material.dart';
import 'package:quran_app/core/widgets/custom_app_bar.dart';
import 'package:quran_app/features/ahadith/domain/entities/hadith.dart';

class HadithView extends StatelessWidget {
  final Hadith hadith;
  const HadithView({super.key, required this.hadith});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(),
      body: SafeArea(child: Column()),
    );
  }
}
