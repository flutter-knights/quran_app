import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/device_size_info.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';

import '../../../../../../config/theme/color_scheme.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';

class MushafPageContent extends StatelessWidget {
  final int pageNumber;

  const MushafPageContent({super.key, required this.pageNumber});

  static const int totalLines = 15;

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
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Center(
                  child: AspectRatio(
                    aspectRatio: 1 / 1.55, // Mushaf page ratio
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final pageWidth = constraints.maxWidth;

                        final lineHeight = pageWidth / 15 * 1.4;
                        final fontSize = pageWidth / 15 * 0.85;
                        final letterSpacing = fontSize * 0.16;

                        return _buildMushafRichText(
                          context,
                          state.pageContent,
                          pageNumber,
                          fontSize,
                          lineHeight,
                          pageWidth,
                          letterSpacing,
                        );
                      },
                    ),
                  ),
                ),
                Center(child: Text(pageNumber.toString())),
              ],
            ),
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
    double fontSize,
    double lineHeight,
    double pageWidth,
    double letterSpacing,
  ) {
    final List<InlineSpan> spans = [];

    int currentSurahIndex = 0;

    for (int i = 0; i < page.ayahs.length; i++) {
      if (page.surahHeadersIndexes.contains(i)) {
        final basmala = page.showBasmalaList[currentSurahIndex];

        spans.add(
          WidgetSpan(
            child: SizedBox(
              width: pageWidth,
              child: SurahHeader(name: page.surahNames[currentSurahIndex]),
            ),
          ),
        );
        if (basmala) {
          spans.add(
            TextSpan(
              text: "\u0021\u0022\u0023\n",
              style: TextStyle(
                fontFamily: "QCF_P000",
                fontSize: fontSize,
                height: lineHeight / fontSize,
                color: context.colorScheme.onSurface,
              ),
            ),
          );
        }
        currentSurahIndex++;
      }

      spans.add(
        TextSpan(
          locale: const Locale('ar'),
          text: page.ayahs[i],
          style: TextStyle(
            fontFamily: "QCF_P${pageIndex.toString().padLeft(3, "0")}",
            fontSize: fontSize,
            height: lineHeight / fontSize,
            // letterSpacing: letterSpacing,
            color: context.colorScheme.onSurface,
          ),
        ),
      );
    }

    return SizedBox(
      width: pageWidth,
      child: RichText(
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.center,
        maxLines: 15,
        overflow: TextOverflow.clip,
        text: TextSpan(children: spans),
      ),
    );
  }
}

class SurahHeader extends StatelessWidget {
  const SurahHeader({
    super.key,
    required this.name,
    this.verseCount = "000",
    this.surahNumber = "116",
  });

  final String name;
  final String verseCount;
  final String surahNumber;

  @override
  Widget build(BuildContext context) {
    final double width = context.width;

    return SizedBox(
      height: width * 0.22, // header occupies ~1 line visually
      child: Stack(
        alignment: Alignment.center,
        children: [
          SvgPicture.asset(
            "assets/images/surah_header.svg",
            width: width,
            fit: BoxFit.fill,
            colorFilter: ColorFilter.mode(
              context.colorScheme.onSurface,
              BlendMode.srcIn,
            ),
          ),

          Positioned(
            top: width * 0.06,
            child: Text(
              name,
              style: TextStyle(
                fontFamily: "QCF_P000",
                fontSize: width * 0.075,
                height: 1.2,
                color: context.colorScheme.onSurface,
              ),
            ),
          ),

          Positioned(
            left: width * 0.18,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("رقمها", style: TS.regular9),
                Text(surahNumber, style: TS.regular10.copyWith(height: 1)),
              ],
            ),
          ),

          Positioned(
            right: width * 0.18,
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text("آياتها", style: TS.regular9),
                Text(verseCount, style: TS.regular10.copyWith(height: 1)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
