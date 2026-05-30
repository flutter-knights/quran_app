import 'package:quran/quran.dart' as quran;
import 'quran_page_service.dart';

/// Metadata for a single Mushaf page: which surah, juz, hizb, and rub
/// (quarter within the hizb) it begins in.
class PageMeta {
  const PageMeta({
    required this.surah,
    required this.juz,
    required this.hizb,
    required this.rub,
  });

  final int surah;

  /// Juz number (1–30).
  final int juz;

  /// Hizb number (1–60). Two hizb per juz.
  final int hizb;

  /// Quarter within the hizb (1–4). Four quarters per hizb.
  final int rub;
}

abstract class QuranMetaService {
  PageMeta getPageMeta(int page);
}

class QuranMetaServiceImpl implements QuranMetaService {
  QuranMetaServiceImpl({required this.pageService});

  final QuranPageService pageService;

  @override
  PageMeta getPageMeta(int page) {
    final first = pageService.getFirstAyahOfPage(page);
    final surahNum = first?.surah ?? 1;
    final ayahNum = first?.ayah ?? 1;
    final abs = _absolute(surahNum, ayahNum);

    // Binary search for the last quarter boundary that is <= abs position.
    var lo = 0;
    var hi = _rubBoundaries.length - 1;
    var q = 0;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (_absolute(_rubBoundaries[mid][0], _rubBoundaries[mid][1]) <= abs) {
        q = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }

    return PageMeta(
      surah: surahNum,
      juz: quran.getJuzNumber(surahNum, ayahNum),
      hizb: (q ~/ 4) + 1,
      rub: (q % 4) + 1,
    );
  }

  static int _absolute(int surah, int ayah) {
    var total = 0;
    for (var s = 1; s < surah; s++) {
      total += quran.getVerseCount(s);
    }
    return total + ayah;
  }

  // ---------------------------------------------------------------------------
  // Authoritative 240 rubʿ-al-hizb (quarter-hizb) start positions.
  // Source: Tanzil Quran Metadata — https://tanzil.net/res/text/metadata/quran-data.xml
  // Each entry is [surah, ayah] of the start of that quarter.
  // Entry 0 (quarter 1) = start of Juz 1: [1, 1]
  // Entry 8 (quarter 9) = start of Juz 2: [2, 142]
  // ---------------------------------------------------------------------------
  static const List<List<int>> _rubBoundaries = [
    [1, 1],    // Q1   – Juz 1 start
    [2, 26],   // Q2
    [2, 44],   // Q3
    [2, 60],   // Q4
    [2, 75],   // Q5
    [2, 92],   // Q6
    [2, 106],  // Q7
    [2, 124],  // Q8
    [2, 142],  // Q9   – Juz 2 start
    [2, 158],  // Q10
    [2, 177],  // Q11
    [2, 189],  // Q12
    [2, 203],  // Q13
    [2, 219],  // Q14
    [2, 233],  // Q15
    [2, 243],  // Q16
    [2, 253],  // Q17  – Juz 3 start
    [2, 263],  // Q18
    [2, 272],  // Q19
    [2, 283],  // Q20
    [3, 15],   // Q21
    [3, 33],   // Q22
    [3, 52],   // Q23
    [3, 75],   // Q24
    [3, 93],   // Q25  – Juz 4 start
    [3, 113],  // Q26
    [3, 133],  // Q27
    [3, 153],  // Q28
    [3, 171],  // Q29
    [3, 186],  // Q30
    [4, 1],    // Q31
    [4, 12],   // Q32
    [4, 24],   // Q33  – Juz 5 start
    [4, 36],   // Q34
    [4, 58],   // Q35
    [4, 74],   // Q36
    [4, 88],   // Q37
    [4, 100],  // Q38
    [4, 114],  // Q39
    [4, 135],  // Q40
    [4, 148],  // Q41  – Juz 6 start
    [4, 163],  // Q42
    [5, 1],    // Q43
    [5, 12],   // Q44
    [5, 27],   // Q45
    [5, 41],   // Q46
    [5, 51],   // Q47
    [5, 67],   // Q48
    [5, 82],   // Q49  – Juz 7 start
    [5, 97],   // Q50
    [5, 109],  // Q51
    [6, 13],   // Q52
    [6, 36],   // Q53
    [6, 59],   // Q54
    [6, 74],   // Q55
    [6, 95],   // Q56
    [6, 111],  // Q57  – Juz 8 start
    [6, 127],  // Q58
    [6, 141],  // Q59
    [6, 151],  // Q60
    [7, 1],    // Q61
    [7, 31],   // Q62
    [7, 47],   // Q63
    [7, 65],   // Q64
    [7, 88],   // Q65  – Juz 9 start
    [7, 117],  // Q66
    [7, 142],  // Q67
    [7, 156],  // Q68
    [7, 171],  // Q69
    [7, 189],  // Q70
    [8, 1],    // Q71
    [8, 22],   // Q72
    [8, 41],   // Q73  – Juz 10 start
    [8, 61],   // Q74
    [9, 1],    // Q75
    [9, 19],   // Q76
    [9, 34],   // Q77
    [9, 46],   // Q78
    [9, 60],   // Q79
    [9, 75],   // Q80
    [9, 93],   // Q81  – Juz 11 start
    [9, 111],  // Q82
    [9, 122],  // Q83
    [10, 11],  // Q84
    [10, 26],  // Q85
    [10, 53],  // Q86
    [10, 71],  // Q87
    [10, 90],  // Q88
    [11, 6],   // Q89  – Juz 12 start
    [11, 24],  // Q90
    [11, 41],  // Q91
    [11, 61],  // Q92
    [11, 84],  // Q93
    [11, 108], // Q94
    [12, 7],   // Q95
    [12, 30],  // Q96
    [12, 53],  // Q97  – Juz 13 start
    [12, 77],  // Q98
    [12, 101], // Q99
    [13, 5],   // Q100
    [13, 19],  // Q101
    [13, 35],  // Q102
    [14, 10],  // Q103
    [14, 28],  // Q104
    [15, 1],   // Q105 – Juz 14 start
    [15, 50],  // Q106
    [16, 1],   // Q107
    [16, 30],  // Q108
    [16, 51],  // Q109
    [16, 75],  // Q110
    [16, 90],  // Q111
    [16, 111], // Q112
    [17, 1],   // Q113 – Juz 15 start
    [17, 23],  // Q114
    [17, 50],  // Q115
    [17, 70],  // Q116
    [17, 99],  // Q117
    [18, 17],  // Q118
    [18, 32],  // Q119
    [18, 51],  // Q120
    [18, 75],  // Q121 – Juz 16 start
    [18, 99],  // Q122
    [19, 22],  // Q123
    [19, 59],  // Q124
    [20, 1],   // Q125
    [20, 55],  // Q126
    [20, 83],  // Q127
    [20, 111], // Q128
    [21, 1],   // Q129 – Juz 17 start
    [21, 29],  // Q130
    [21, 51],  // Q131
    [21, 83],  // Q132
    [22, 1],   // Q133
    [22, 19],  // Q134
    [22, 38],  // Q135
    [22, 60],  // Q136
    [23, 1],   // Q137 – Juz 18 start
    [23, 36],  // Q138
    [23, 75],  // Q139
    [24, 1],   // Q140
    [24, 21],  // Q141
    [24, 35],  // Q142
    [24, 53],  // Q143
    [25, 1],   // Q144
    [25, 21],  // Q145 – Juz 19 start
    [25, 53],  // Q146
    [26, 1],   // Q147
    [26, 52],  // Q148
    [26, 111], // Q149
    [26, 181], // Q150
    [27, 1],   // Q151
    [27, 27],  // Q152
    [27, 56],  // Q153 – Juz 20 start
    [27, 82],  // Q154
    [28, 12],  // Q155
    [28, 29],  // Q156
    [28, 51],  // Q157
    [28, 76],  // Q158
    [29, 1],   // Q159
    [29, 26],  // Q160
    [29, 46],  // Q161 – Juz 21 start
    [30, 1],   // Q162
    [30, 31],  // Q163
    [30, 54],  // Q164
    [31, 22],  // Q165
    [32, 11],  // Q166
    [33, 1],   // Q167
    [33, 18],  // Q168
    [33, 31],  // Q169 – Juz 22 start
    [33, 51],  // Q170
    [33, 60],  // Q171
    [34, 10],  // Q172
    [34, 24],  // Q173
    [34, 46],  // Q174
    [35, 15],  // Q175
    [35, 41],  // Q176
    [36, 28],  // Q177 – Juz 23 start
    [36, 60],  // Q178
    [37, 22],  // Q179
    [37, 83],  // Q180
    [37, 145], // Q181
    [38, 21],  // Q182
    [38, 52],  // Q183
    [39, 8],   // Q184
    [39, 32],  // Q185 – Juz 24 start
    [39, 53],  // Q186
    [40, 1],   // Q187
    [40, 21],  // Q188
    [40, 41],  // Q189
    [40, 66],  // Q190
    [41, 9],   // Q191
    [41, 25],  // Q192
    [41, 47],  // Q193 – Juz 25 start
    [42, 13],  // Q194
    [42, 27],  // Q195
    [42, 51],  // Q196
    [43, 24],  // Q197
    [43, 57],  // Q198
    [44, 17],  // Q199
    [45, 12],  // Q200
    [46, 1],   // Q201 – Juz 26 start
    [46, 21],  // Q202
    [47, 10],  // Q203
    [47, 33],  // Q204
    [48, 18],  // Q205
    [49, 1],   // Q206
    [49, 14],  // Q207
    [50, 27],  // Q208
    [51, 31],  // Q209 – Juz 27 start
    [52, 24],  // Q210
    [53, 26],  // Q211
    [54, 9],   // Q212
    [55, 1],   // Q213
    [56, 1],   // Q214
    [56, 75],  // Q215
    [57, 16],  // Q216
    [58, 1],   // Q217 – Juz 28 start
    [58, 14],  // Q218
    [59, 11],  // Q219
    [60, 7],   // Q220
    [62, 1],   // Q221
    [63, 4],   // Q222
    [65, 1],   // Q223
    [66, 1],   // Q224
    [67, 1],   // Q225 – Juz 29 start
    [68, 1],   // Q226
    [69, 1],   // Q227
    [70, 19],  // Q228
    [72, 1],   // Q229
    [73, 20],  // Q230
    [75, 1],   // Q231
    [76, 19],  // Q232
    [78, 1],   // Q233 – Juz 30 start
    [80, 1],   // Q234
    [82, 1],   // Q235
    [84, 1],   // Q236
    [87, 1],   // Q237
    [90, 1],   // Q238
    [94, 1],   // Q239
    [100, 9],  // Q240
  ];

  /// Exposed for testing — do not use in application code.
  static const List<List<int>> debugRubBoundaries = _rubBoundaries;
}
