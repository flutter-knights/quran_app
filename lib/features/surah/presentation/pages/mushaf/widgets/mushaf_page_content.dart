import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran_app/config/theme/color_scheme.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';

class MushafPageContent extends StatelessWidget {
  final int pageNumber;

  const MushafPageContent({super.key, required this.pageNumber});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MushafCubit, MushafState>(
      builder: (context, state) {
        if (state is MushafLoading) {
          return const Center(child: CircularProgressIndicator());
        }

        if (state is MushafError) {
          return Center(child: Text(state.message));
        }

        if (state is MushafLoaded) {
          return Padding(
            padding: const EdgeInsets.only(top: 16, left: 16, right: 16),
            child: _buildMushafRichText(context, state.pageContent, pageNumber),
          );
        }

        return const SizedBox();
      },
    );
  }

  Widget _buildMushafRichText(
    BuildContext context,
    MushafPageEntity page,
    int pageIndex,
  ) {
    final List<InlineSpan> spans = [];
    int currentSurahIndex = 0;

    for (int i = 0; i < page.ayahs.length; i++) {
      // Surah header
      if (page.surahHeadersIndexes.contains(i)) {
        final name = page.surahNames[currentSurahIndex];
        final basmala = page.showBasmalaList[currentSurahIndex];

        spans.add(
          TextSpan(
            text: "\n$name\n",
            style: const TextStyle(fontFamily: "QCF_P000", fontSize: 40),
          ),
        );

        if (basmala) {
          spans.add(
            const TextSpan(
              text: "﷽\n",
              style: TextStyle(fontFamily: "QCF_P000", fontSize: 26),
            ),
          );
        }

        currentSurahIndex++;
      }

      // Ayah text
      spans.add(
        TextSpan(
          text: page.ayahs[i],
          style: TextStyle(
            fontFamily: "QCF_P${pageIndex.toString().padLeft(3, "0")}",
            fontSize: 23,
          ),
        ),
      );
    }

    return RichText(
      textDirection: TextDirection.rtl,
      locale: const Locale('ar'),
      textAlign: TextAlign.start, // 🔥 IMPORTANT
      text: TextSpan(
        children: spans,
        style: TextStyle(
          color: context.colorScheme.onSurface,
          letterSpacing: 0,
          wordSpacing: 0,
          height: null,
          fontFamilyFallback: const [],
        ),
      ),
    );
  }
}
