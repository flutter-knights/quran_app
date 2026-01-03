import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';

import 'package:quran_app/config/theme/typography_styles.dart';
import 'package:quran_app/core/constants/device_size_info.dart';
import 'package:quran_app/features/surah/domain/entities/mushaf_page_entity.dart';

import '../../../../../../config/theme/color_scheme.dart';
import '../../../cubit/mushaf/mushaf_cubit.dart';
import '../../../cubit/mushaf/mushaf_state.dart';

/// 🌍 GLOBAL TUNING (بس كده)
class MushafTuning {
  static double fontSizeFactor = 0.85;
  static double letterSpacingFactor = 0.16;
}

class MushafPageContent extends StatefulWidget {
  final int pageNumber;

  const MushafPageContent({super.key, required this.pageNumber});

  @override
  State<MushafPageContent> createState() => _MushafPageContentState();
}

class _MushafPageContentState extends State<MushafPageContent> {
  static const int totalLines = 15;

  double _round3(double v) => (v * 1000).round() / 1000;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        /// 🎚 Sliders
        _buildSliders(),

        /// 📄 Mushaf Page
        Expanded(
          child: BlocBuilder<MushafCubit, MushafState>(
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
                  child: Center(
                    child: AspectRatio(
                      aspectRatio: 1 / 1.55,
                      child: LayoutBuilder(
                        builder: (context, constraints) {
                          final pageWidth = constraints.maxWidth;

                          final lineHeight = pageWidth / totalLines * 1.4;

                          final fontSize =
                              pageWidth /
                              totalLines *
                              MushafTuning.fontSizeFactor;

                          final letterSpacing =
                              fontSize * MushafTuning.letterSpacingFactor;

                          return _buildMushafRichText(
                            context,
                            state.pageContent,
                            widget.pageNumber,
                            fontSize,
                            lineHeight,
                            pageWidth,
                            letterSpacing,
                          );
                        },
                      ),
                    ),
                  ),
                );
              }

              return const SizedBox();
            },
          ),
        ),
      ],
    );
  }

  /// 🎚 SLIDERS (GLOBAL ONLY)
  Widget _buildSliders() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Column(
        children: [
          // 🔠 Font size
          Row(
            children: [
              const SizedBox(width: 70, child: Text("Font")),
              Expanded(
                child: Slider(
                  value: MushafTuning.fontSizeFactor,
                  min: 0.6,
                  max: 1.1,
                  divisions: ((1.1 - 0.6) / 0.001).round(),
                  label: MushafTuning.fontSizeFactor.toStringAsFixed(3),
                  onChanged: (v) {
                    setState(() {
                      MushafTuning.fontSizeFactor = _round3(v);
                    });
                    debugPrint(
                      "FontSizeFactor = ${MushafTuning.fontSizeFactor}",
                    );
                  },
                ),
              ),
            ],
          ),

          // 🔡 Letter spacing
          Row(
            children: [
              const SizedBox(width: 70, child: Text("Spacing")),
              Expanded(
                child: Slider(
                  value: MushafTuning.letterSpacingFactor,
                  min: 0.05,
                  max: 0.30,
                  divisions: ((0.30 - 0.05) / 0.001).round(),
                  label: MushafTuning.letterSpacingFactor.toStringAsFixed(3),
                  onChanged: (v) {
                    setState(() {
                      MushafTuning.letterSpacingFactor = _round3(v);
                    });
                    debugPrint(
                      "LetterSpacingFactor = ${MushafTuning.letterSpacingFactor}",
                    );
                  },
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// 🧾 Mushaf Text
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
            letterSpacing: letterSpacing,
            color: context.colorScheme.onSurface,
          ),
        ),
      );
    }

    return SizedBox(
      width: pageWidth,
      child: RichText(
        textDirection: TextDirection.rtl,
        textAlign: TextAlign.start,
        maxLines: totalLines,
        overflow: TextOverflow.clip,
        text: TextSpan(children: spans),
      ),
    );
  }
}

/// 🏷 Surah Header
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
      height: width * 0.22,
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
              children: [
                Text("رقمها", style: TS.regular9),
                Text(surahNumber, style: TS.regular10.copyWith(height: 1)),
              ],
            ),
          ),
          Positioned(
            right: width * 0.18,
            child: Column(
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
